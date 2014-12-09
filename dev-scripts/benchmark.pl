
{

    package A;
    use Moose;

    has i => ( is => 'ro', isa => 'Int' );
}

{

    package C;
    use Moose;
    with 'MooseX::Failover';

    has i => ( is => 'ro', isa => 'Int' );
}

{

    package D;
    use Moose;
    has i => ( is => 'ro', isa => 'Str' );
}

use Benchmark qw/ cmpthese /;
use Try::Tiny;

use common::sense;

sub failover {
    C->new( i => 'x', failover_to => 'D' );
}

sub try_catch {
    try { A->new( i => 'x' ) } catch { D->new( i => 'x' ) };
}

sub eval_block {
    eval { A->new( i => 'x' ) } // D->new( i => 'x' );
}

sub failover_ok {
    C->new( i => '1', failover_to => 'D' );
}

sub try_catch_ok {
    try { A->new( i => '1' ) } catch { D->new( i => '1' ) };
}

sub eval_block_ok {
    eval { A->new( i => '1' ) } // D->new( i => '1' );
}

cmpthese(
    10_000,
    {
        failover   => 'failover',
        try_catch  => 'try_catch',
        eval_block => 'eval_block',
    }
);

cmpthese(
    10_000,
    {
        failover   => 'failover_ok',
        try_catch  => 'try_catch_ok',
        eval_block => 'eval_block_ok',
    }
);

