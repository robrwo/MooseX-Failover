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
    note "errors with no failover";

    throws_ok {
        my $obj = Sub1->new( num => 123, );
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

done_testing;
