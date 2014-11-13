package MooseX::Monadic;

use Moose;

use aliased 'Moose::Exception::AttributeIsRequired';
use aliased 'Moose::Exception::ValidationFailedForTypeConstraint';

use Carp;
use Class::Load qw/ try_load_class /;
use Try::Tiny;

has as_class => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]',
    builder    => '_build_as_class',
    init_arg   => 'as',
    auto_deref => 1,
);

sub _build_as_class {
    my ($self) = @_;
    [];
}

has class_error => (
    is        => 'ro',
    writer    => '_set_class_error',
    predicate => 'has_class_error',
    clearer   => 'clear_class_error',
    init_arg  => undef,
);

sub CHECK_CONSTRAINTS {
    my ( $self, $args ) = @_;

    my $meta = $self->meta
      or return;

    foreach my $attr ( $meta->get_all_attributes ) {

        next unless defined $attr->init_arg;    # Skip if no init_arg

        # Skip, because the initializer calls the writer to set
        # the initial value.  We have no means of testing the
        # value before it's set (and it may not even be used by
        # the initializer).

        next if $attr->has_initializer;

        my $arg_name = $attr->init_arg;

        if ( exists $args->{$arg_name} ) {

            if ( my $constraint = $attr->type_constraint ) {

                my $value = $args->{$arg_name};

                my $error = $constraint->validate(
                      $constraint->has_coercion
                    ? $constraint->coerce($value)
                    : $value
                );

                if ($error) {
                    return ValidationFailedForTypeConstraint->new(
                        error_message => $error,
                        value         => $value,
                        type          => $constraint
                    );
                }

            }

        }
        elsif ( $attr->is_required ) {

            next if $attr->has_default || $attr->has_builder;

            return AttributeIsRequired->new(
                class_name     => ref($self),
                attribute_name => $arg_name,
                params         => $args,
            );

        }

    }

    return;

}

sub BUILD {
    my ( $self, $args ) = @_;

    my $base_class = ref($self);
    my $base_meta  = $self->meta;

    foreach my $as_class ( $self->as_class ) {

        try_load_class($as_class) or confess "Unable to load ${as_class}";

        confess "${as_class} is not a ${base_class}"
          unless $as_class->isa($base_class);

        my $meta = $as_class->meta;

        if ( my $error = $as_class->CHECK_CONSTRAINTS($args) ) {

            $self->_set_class_error($error);

        }
        else {

            try {
                $meta->rebless_instance( $self, %{$args} );

                # Reblessing does not actually call BUILD,
                # so we do this manually.

                my $stash = $meta->{_package_stash};
                if ( my $build = $stash->get_symbol('&BUILD') ) {
                    $self->$build();
                }

            }
            catch {

                # Note that we have no control of any side
                # effects from calling BUILD.

                my $error = $_;
                $base_meta->rebless_instance_back($self);
                $self->_set_class_error($error);

            };

        }

        last if ref($self) ne $base_class;

    }

}

no Moose;

1;
