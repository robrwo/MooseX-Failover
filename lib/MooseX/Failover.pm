package MooseX::Failover;

use Moose::Role;

use Carp;
use Class::Load qw/ try_load_class /;

use version 0.77; our $VERSION = version->declare('v0.1.3');

# RECOMMEND PREREQ: Class::Load::XS

=head1 NAME

MooseX::Failover - Instantiate Moose classes with failover

=for readme plugin version

=head1 SYNOPSIS

  # In your class:

  package MyClass;

  use Moose;
  with 'MooseX::Failover';

  # When using the class

  my $obj = MyClass->new( %args, failover_to => 'OtherClass' );

  # If %args contains missing or invalid values or new otherwise
  # fails, then $obj will be of type "OtherClass".

=begin :readme

=head1 INSTALLATION

See
L<How to install CPAN modules|http://www.cpan.org/modules/INSTALL.html>.

=for readme plugin requires heading-level=2 title="Required Modules"

=for readme plugin changes

=end :readme

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

Note that your failover class should support the same methods as the
original class.  A use case for this role would be for instantiating
L<Web::Machine::Resource> objects, where the failover is a
Web::Machine::Resource object that returns an error page.

Ideally, your failover class would satisy the Liskov Substitution
Principle, so that (roughly) all provable properties of the original
class are also provable of the failover class.  In practice, we only
care about the properties (methods and attributes) that are actually
used in our programs.

=for readme stop

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
      is       => 'ro',
      isa      => 'HashRef',
      init_arg => undef,
      default  => sub {
          {
              class   => 'Failover',
              err_arg => 'error',
          };
      },
  );

Failover attributes from parent classes are not used. (This
restriction is to improve the performance.)

=cut

around new => sub {
    my ( $orig, $class, %args ) = @_;

    my $attr = $class->meta->get_attribute('failover_to');
    my $key = $attr ? $attr->init_arg : 'failover_to';

    my $failover;

    $failover = $args{$key} if defined $key;
    if ( !$failover and $attr ) {
        my $builder = $attr->builder // $attr->default // return;
        $failover = $class->$builder();
    }

    my $next = ( ref $failover ) ? $failover : { class => $failover };

    $next->{err_arg} = 'error' unless exists $next->{err_arg};

    eval { $class->$orig(%args) } // do {

        my $error = $@;
        my $next_next;
        my $next_class = $next->{class};
        if ( ref $next_class ) {
            $next_class = shift @{ $next->{class} };
            $next_next  = $next;
        }

        croak $error unless $next_class;

        try_load_class($next_class)
          or croak "unable to load class ${next_class}";

        %args = %{ $next->{args} } if $next->{args};

        $args{ $next->{err_arg} } = $error if defined $next->{err_arg};
        $args{failover_to} = $next_next if $next_next;

        $next_class->new( %args, );
    };

};

=for readme continue

=head1 AUTHOR

Robert Rothenberg C<<rrwo@thermeon.com>>

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
