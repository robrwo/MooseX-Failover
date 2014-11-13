use Test::Most;

{

    package Base;

    use Moose;
    extends 'MooseX::Monadic';

    1;
}

{

    package Sub1;

    use Moose;
    extends 'Base';

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
    my $obj = Base->new();
    isa_ok $obj, 'MooseX::Monadic';
    isa_ok $obj, 'Base';
    ok !$obj->has_class_error, 'no errors';
}

{
    my $obj = Base->new(
        as    => [qw/ Sub1 /],
        num   => 1,
        r_str => 'x',
    );
    isa_ok $obj, 'MooseX::Monadic';
    isa_ok $obj, 'Base';
    isa_ok $obj, 'Sub1';
    ok !$obj->has_class_error, 'no errors';
}

{
    my $obj = Base->new(
        as    => [qw/ Sub1 /],
        num   => 'x',
        r_str => 'x',
    );
    isa_ok $obj, 'MooseX::Monadic';
    isa_ok $obj, 'Base';
    ok !$obj->isa('Sub1'), 'not a Sub1';
    ok $obj->has_class_error, 'has error';

    ok my $error = $obj->class_error, 'got error';

    isa_ok $error,
      'Moose::Exception::ValidationFailedForTypeConstraint';

    is $error->attribute->name, 'num', 'attribute';
    is $error->value, 'x', 'value';

}

{
    my $obj = Base->new(
        as    => [qw/ Sub1 /],
    );
    isa_ok $obj, 'MooseX::Monadic';
    isa_ok $obj, 'Base';
    ok !$obj->isa('Sub1'), 'not a Sub1';
    ok $obj->has_class_error, 'has error';

    ok my $error = $obj->class_error, 'got error';

    isa_ok $error,
      'Moose::Exception::AttributeIsRequired';

    is $error->attribute_name, 'r_str', 'attribute_name';
    is $error->class_name, 'Sub1';
}


done_testing;
