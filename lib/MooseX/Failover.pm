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

  # In your class:

  package MyClass;

  use Moose;
  with 'MooseX::Failover';

  # When using the class

  my $obj = MyClass->new( %args, failover_to => 'OtherClass' );

  # If %args contains missing or invalid values or new otherwise
  # fails, then $obj will be of type "OtherClass".

=head1 DESCRIPTION

WARNING: This is a purely speculative module, and will be rewritten or
scrapped entirely.

This role provides constructor failover for L<Moose> classes.

If a class cannot be instantiated because of invalid arguments
(perhaps from an untrusted source), then instead it returns the
failover class (passing the same arguments to that class).

This allows for cleaner design, by not forcing you to duplicate type
checking for class parameters.

=head1 ARGUMENTS

=head2 C<failover_to>

This argument should contain a hash reference with the following keys:

=over

=item C<class>

The name of the class to fail over to.

This can be an array reference of multiple classes.

=item C<args>

An array reference of arguments to pass to the failover class.  When
omitted, then the same arguments will be passed to it.

=item C<err_arg>

This is the name of the constructor argument to pass the error to (it
defaults to "error".  This is useful if the failover class can inspect
the error and act appropriately.

For example, if the original class is a handler for a website, where
the attributes correspond to URL parameters, then the failover class
can return HTTP 400 responses if the errors are for invalid
parameters.

To disable it, set it to C<undef>.

=back

Note that

  failover_to => 'OtherClass'

is equivalent to

  failover_to => { class => 'OtherClass' }

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
      : { class => $args->{failover_to}, err_arg => 'error' };

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

    my $continue = 0;
    if ( ref $next_class ) {
      $next_class = shift @{ $next->{class} };
      $continue = 1;
    }

    try_load_class($next_class)
      or croak "unable to load class ${next_class}";

    my @next_args = @{ $next->{args} // $l_args };
    if ( $next->{err_arg} ) {
        push @next_args, $next->{err_arg} => $error;
    }
    if ($continue) {
      push @next_args, failover_to => $next;
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
