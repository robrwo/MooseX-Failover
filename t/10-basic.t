use Test::Most;

{

    package Sub1;

    use Moose;
    with 'MooseX::Failover';

    has num => (
        is  => 'ro',
        isa => 'Int',
    );

    has r_str => (
        is       => 'ro',
        isa      => 'Str',
        required => 1,
    );

    has d_str => (
        is       => 'ro',
        isa      => 'Str',
        required => 1,
        default  => 'wibble',
    );

}

{

    package Sub2;

    use Moose;
    extends 'Sub1';

    has q_str => (
        is       => 'ro',
        isa      => 'Str',
        required => 1,
        init_arg => 'str',
    );

}

{

    package Sub3;

    use Moose;
    with 'MooseX::Failover';

    has num => (
        is  => 'ro',
        isa => 'Int',
    );

    has failover_to => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub {
            {
                class   => 'Failover',
                err_arg => 'error',
            };
        },
        init_arg => undef,
    );
}

{

    package Sub4;

    use Moose;
    with 'MooseX::Failover';

    has num => (
        is  => 'ro',
        isa => 'Int',
    );

    has failover_to => (
        is       => 'ro',
        isa      => 'HashRef',
        init_arg => 'err_to',
    );
}

{

    package Sub5;

    use Moose;
    with 'MooseX::Failover';

    has num => (
        is  => 'ro',
        isa => 'Int',
    );

    has failover_to => (
        is      => 'ro',
        isa     => 'HashRef',
        builder => '_build_failover_to',
    );

    sub _build_failover_to {
        return {
            class   => 'Failover',
            err_arg => 'error',
        };
    }
}

{

    package Failover;

    use Moose;

    has error => ( is => 'ro', );

}

{
    note "no errors";

    my $obj = Sub1->new(
        num   => 123,
        r_str => 'test',
    );

    isa_ok $obj, 'Sub1';
}

{
    note "no errors";

    my $obj = Sub2->new(
        num   => 123,
        r_str => 'test',
        str   => 'foo',
    );

    isa_ok $obj, 'Sub1';
    isa_ok $obj, 'Sub2';
}

{
    note "errors with no failover";

    throws_ok {
        my $obj = Sub1->new( num => 123, );
        fail 'no object';
    }
    qr/Attribute \(r_str\) is required/, 'expected error';

}

{
    note "errors with failover";

    my $obj = Sub1->new(
        num         => 123,
        failover_to => 'Failover',
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub1->new(
        num         => 123,
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
    isa_ok $obj->error, 'Moose::Exception::AttributeIsRequired';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub2->new(
        num         => 123,
        r_str       => 'test',
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
    isa_ok $obj->error, 'Moose::Exception::AttributeIsRequired';
}

{
    note "errors with failover (err_arg)";

    my $obj = Sub1->new(
        num         => '123x',
        r_str       => 'test',
        failover_to => {
            class   => 'Failover',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Failover';
    isa_ok $obj->error, 'Moose::Exception::ValidationFailedForTypeConstraint';
}

{
    note "errors with failover (err_arg ignored)";

    my $obj = Sub2->new(
        num         => 123,
        r_str       => 'test',
        failover_to => {
            class   => 'Sub1',
            err_arg => 'error',
        },
    );

    isa_ok $obj, 'Sub1';
    ok !$obj->can('error'), 'no error attribute';
}

{
    note "errors with failover (err_arg ignored)";

    my %args = ( num => 123 );

    my $obj = Sub2->new(
        %args,
        failover_to => {
            class => 'Sub1',
            args  => {
                %args,
                failover_to => {
                    class   => 'Failover',
                    err_arg => 'error',
                }
            },
        },

    );

    isa_ok $obj, 'Failover';
    isa_ok $obj->error, 'Moose::Exception::AttributeIsRequired';
}

{
    note "errors with failover (err_arg ignored, list of classes)";

    my %args = ( num => 123 );

    my $obj = Sub2->new(
        %args,
        failover_to => {
            class   => [qw/ Sub1 Failover /],
            err_arg => 'error',
            args    => \%args,
        },
    );

    isa_ok $obj, 'Failover';
    isa_ok $obj->error, 'Moose::Exception::AttributeIsRequired';
}

{
    note "bad failover";

    my %args = ( num => 123 );

    throws_ok {
        my $obj = Sub2->new(
            %args,
            failover_to => {
                class   => [qw/ Sub1 Sub1 /],
                err_arg => 'error',
                args    => \%args,
            },
        );
        fail 'no object';
    }
    qr/Attribute \(r_str\) is required/, 'bad failover';
}

{
    note "errors with failover (in class def)";

    my $obj = Sub3->new( num => 'x', );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (in class def)";

    my $obj = Sub3->new(
        num         => 'x',
        failover_to => 'Invalid',    # ignored
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (in class def)";

    my $obj = Sub4->new(
        num    => 'x',
        err_to => 'Failover',
    );

    isa_ok $obj, 'Failover';
}

{
    note "errors with failover (in class def)";

    my $obj = Sub5->new( num => 'x', );

    isa_ok $obj, 'Failover';
}

done_testing;
