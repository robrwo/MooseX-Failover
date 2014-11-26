use lib 'lib';

{
    package Local::Resource::Foo;

    use Moose;
    use MooseX::NonMoose;

    extends 'Web::Machine::Resource';
    with 'MooseX::Failover';

    has 'arg' => (
        is       => 'ro',
        isa      => 'Int',
        required => 1,
    );

    sub content_types_provided {
        [
            {
                'text/plain' => 'foo_text',
            }
        ];
    }

    sub foo_text {
        my ($self) = @_;
        $self->response->body( "foo.arg = " . $self->arg . "\n" );
    }

}

{
    package Local::Resource::Error;

    use Moose;
    use MooseX::NonMoose;

    extends 'Web::Machine::Resource';

    has error => ( is => 'ro', );

    has status => (
        is      => 'rw',
        isa     => 'Int',
        default => 500,
    );

    sub content_types_provided {
        [
            {
                'text/plain' => 'error_text',
            }
        ];
    }

    sub error_text {
        my ($self) = @_;

        my $error = $self->error;
        if ( blessed($error)
            && $error->isa(
                'Moose::Exception::ValidationFailedForTypeConstraint') )
        {

            $self->status(400);
            return 'Invalid argument';

        }

        return 'Internal error';
    }

    sub finish_request {
        my ($self) = @_;
        $self->response->status( $self->status );
    }

}

{

    package Local::App;

    use Web::Simple;
    use Web::Machine;

    use Local::Resource::Foo;

    use common::sense;

    sub dispatch_request {
        ( 'GET + /foo/*' => 'foo', );
    }

    sub foo {
        my ( $self, $arg ) = @_;

        Web::Machine->new(
            resource      => 'Local::Resource::Foo',
            resource_args => [
                arg         => $arg,
                failover_to => {
                    class   => 'Local::Resource::Error',
                    err_arg => 'error',
                },
            ],
        );
    }

}

use Local::App;

use common::sense;

Local::App->run_if_script;
