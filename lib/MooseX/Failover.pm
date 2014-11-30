package MooseX::Failover;

use Moose::Role;

use Carp;
use Class::Load qw/ try_load_class /;
use PerlX::Maybe;

use version 0.77; our $VERSION = version->declare('v0.1.0');

# RECOMMEND PREREQ: Class::Load::XS
# RECOMMEND PREREQ: PerlX::Maybe::XS

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

This role provides constructor failover for L<Moose> classes.

If a class cannot be instantiated because of invalid arguments
(perhaps from an untrusted source), then instead it returns the
failover class (passing the same arguments to that class).

This allows for cleaner design, by not forcing you to duplicate type
checking for class parameters.

Note that this is roughly equivalent to using

  my $obj = eval { MyClass->new(%args) //
     OtherClass->new( %args, error => $@ );

=head1 ARGUMENTS

=head2 C<failover_to>

This argument should contain a hash reference with the following keys:

=over

=item C<class>

The name of the class to fail over to.

This can be an array reference of multiple classes.

=item C<args>

A hash reference of arguments to pass to the failover class.  When
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

Note that this is not an attribute.  You can specify a default
failover as part of the class definition by defining an attribute:

  has failover_to => (
      is      => 'ro',
      isa     => 'HashRef',
      default => sub {
          {
              class   => 'Failover',
              err_arg => 'error',
          };
      },
  );

Note that changing the C<init_arg> of the attribute will have no
effect.  This can always be overridden in the constructor.

=head1 METHODS

=cut

around new => sub {
    my ( $orig, $class, %args ) = @_;

    my $failover = $args{failover_to} // $class->_get_failover;

    my $next = ( ref $failover ) ? $failover : { class => $failover };

    $next->{err_arg} = 'error' unless exists $next->{err_arg};

    eval { $class->$orig(%args) } || $class->_failover_new( $next, $@, \%args );
};

sub _get_failover {
    my ($class) = @_;

    my $attr = $class->meta->find_attribute_by_name('failover_to')
      or return;

    my $builder = $attr->builder // $attr->default // return;
    $class->$builder();
}

sub _failover_new {
    my ( $class, $next, $error, $args ) = @_;

    my $next_next;
    my $next_class = $next->{class};
    if ( ref $next_class ) {
        $next_class = shift @{ $next->{class} };
        $next_next  = $next;
    }

    croak $error unless $next_class;

    try_load_class($next_class)
      or croak "unable to load class ${next_class}";

    $next_class->new(
        %{ $next->{args} // $args },
        maybe $next->{err_arg} => $error,
        maybe 'failover_to'    => $next_next,
    );
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
