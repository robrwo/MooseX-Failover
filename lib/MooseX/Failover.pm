package MooseX::Failover;

use Moose::Role;

use aliased 'Moose::Exception::AttributeIsRequired';
use aliased 'Moose::Exception::ValidationFailedForTypeConstraint';

use Carp;
use Class::Load qw/ try_load_class /;
use Try::Tiny;

use version 0.77; our $VERSION = version->declare('v0.1.0');

=head1 NAME

MooseX::Failover - Instantiate Moose classes with failover

=head1 SYNOPSIS


=head1 DESCRIPTION

WARNING: This is a purely speculative module, and will be rewritten or
scrapped entirely.


=head1 ATTRIBUTES

=cut

=head1 METHODS

=cut

around new => sub {
    my ( $orig, $class, @args ) = @_;

    my $args = $class->BUILDARGS(@args);

    # TODO: no failover_to

    my $next =
      ( ref $args->{failover_to} )
      ? $args->{failover_to}
      : { class => $args->{failover_to} };

    if ( my $error = $class->CHECKARGS($args) ) {
        return $class->_next_new( $next, $error, \@args );
    }

    try {
        return $class->$orig(@args);
    }
    catch {
        return $class->_next_new( $next, $_, \@args );
    };
};

sub _next_new {
    my ( $class, $next, $error, $l_args ) = @_;

    my $next_class = $next->{class}
      or croak $error;

    try_load_class($next_class)
      or croak "unable to load class ${next_class}";

    my @next_args = @{ $next->{args} // $l_args };
    if ( $next->{err_arg} ) {
        push @next_args, $next->{err_arg} => $error;
    }

    return $next_class->new(@next_args);
}

=head2 C<CHECKARGS>

  if (my $error = $class->CHECKARGS( \%args )) {
    ...
    }

This is an internal method used for checking whether a hash reference
of arguments meets the type or requirement constraints of the
constructor, without actually trying to construct the object.

=cut

sub CHECKARGS {
    my ( $class, $args ) = @_;

    my $meta = $class->meta
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
                class_name => ref($class) || $class,
                attribute_name => $attr->name,
                params         => $args,
            );

        }
    }

    return;
}

=head1 AUTHOR

Robert Rothenberg C<<rrwo@cpan.org>>

=head1 Acknowledgements

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
