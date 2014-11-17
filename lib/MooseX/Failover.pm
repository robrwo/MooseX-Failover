package MooseX::Failover;

use Moose;

use aliased 'Moose::Exception::AttributeIsRequired';
use aliased 'Moose::Exception::ValidationFailedForTypeConstraint';

use Carp;
use Class::Load qw/ try_load_class /;
use Try::Tiny;

use version 0.77; our $VERSION = version->declare('v0.1.0');

=head1 NAME

MooseX::Failover - Instantiate Moose classes with failover

=head1 SYNOPSIS

  {
    package Base;

    use Moose;
    extends 'MooseX::Failover';
  }

  {
    package Sub1;

    use Moose;
    extends 'Base';

    has num => (
        is  => 'ro',
        isa => 'Int',
    );
  }

  ...

  my $obj = Base->new(
    as  => [ 'Sub1' ],
    num => $unreliable_source,
  );

  if ($obj->has_class_error) {

    if ($obj->class_error
      ->isa('Moose::Exception::ValidationFailedForTypeConstraint') {

      # User error, e.g. HTTP 400

    } else {

      # Possible system error, e.g. HTTP 500

    }

  }

=head1 DESCRIPTION

WARNING: This is a purely speculative module, and will be rewritten or
scrapped entirely.

This is a L<Moose> extension that allows you to instantiate objects
that will will fail over on construction and return an alternative
class if there is a problem.

The use case is for classes in systems with unreliable input. It
allows you to create a base class that can handle errors, but use
subclasses where the attributes correspond to use input.

For example, you could use this for a L<Web::Machine::Resource> class
where the attributes correspond to URL paramaters.  If an invalid
parameter is given, then the base class can handle this gracefully
instead of treating it as an internal server error.

It works by first checking the type constraints of the attributes, to
see if there are any obvious errors that might cause instantiation to
fail.  If they succeed, it then calls the C<BUILD> method and checks
for failures there.

=head1 ATTRIBUTES

=head2 C<as_class>

This contains a list of subclasses to instantiate the object as. The
first one that succeeds is used. Later classes are fallback classes.

Note: in the constructor, use C<as>.

=cut

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

=head2 C<class_error>

If there was an error, then C<has_class_error> is true and
C<class_error> returns the error from the last unucessful attempt to
instantiate a class.

Note that if there are multiple failover classes, then earlier
failures will be lost.

=cut

has class_error => (
    is        => 'ro',
    writer    => '_set_class_error',
    predicate => 'has_class_error',
    clearer   => 'clear_class_error',
    init_arg  => undef,
);

=head1 METHODS

=cut

around BUILDARGS => sub {
  my ($orig, $class, %args) = @_;
  $args{_BUILDARGS} //= { %args };
  $class->$orig(%args);
};

=head2 C<CHECKARGS>

  if (my $error = $class->CHECKARGS( \%args )) {
    ...
    }

This is an internal method used for checking whether a hash reference
of arguments meets the type or requirement constraints of the
constructor, without actually trying to construct the object.

=cut

sub CHECKARGS {
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
                        value     => $value,
                        type      => $constraint,
                        attribute => $attr,
                    );
                }

            }

        }
        elsif ( $attr->is_required ) {

            next if $attr->has_default || $attr->has_builder;

            return AttributeIsRequired->new(
                class_name     => ref($self) || $self,
                attribute_name => $attr->name,
                params         => $args,
            );

        }

    }

    return;

}

sub BUILD {
    my ( $self, $base_args ) = @_;

    my $base_class = ref($self);
    my $base_meta  = $self->meta;

    foreach my $as_class ( $self->as_class ) {

        try_load_class($as_class) or confess "Unable to load ${as_class}";

        confess "${as_class} is not a ${base_class}"
          unless $as_class->isa($base_class);

        my $meta = $as_class->meta;
        my $args = $as_class->BUILDARGS( %{ $base_args->{_BUILDARGS} } );

        if ( my $error = $as_class->CHECKARGS($args) ) {

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

=head1 KNOWN ISSUES

=head2 C<BUILDARGS>

Because C<BUILDARGS> should be called in the superclass, what the
extension tries to do is save the original arguments in the
"_BUILDARGS" key and pass them to the classes before checking argument
validity.

If your base class modifies C<BUILDARGS>, then it will need to save
the original arguments in that key before calling the original.

=head1 AUTHOR

Robert Rothenberg C<<rrwo@cpan.org>>

=head1 Acknowledgements and Contributors

=over

=item Thermeon Europe.

=item Piers Cawley.

=back

=head1 COPYRIGHT

Copyright 2014 Thermeon Europe.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

no Moose;

1;
