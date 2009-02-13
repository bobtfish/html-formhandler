use Test::More tests => 14;

use lib 't/lib';

use_ok( 'HTML::FormHandler' );

use_ok( 'Form::Two' );

my $form = Form::Two->new;

ok( $form, 'get subclassed form' );

is( $form->field('optname')->temp, 'Txxt', 'new field');

ok( $form->field('reqname'), 'get old field' );

ok( $form->field('fruit'), 'fruit field' );

use_ok( 'Form::Test' );

$form = Form::Test->new;

ok( $form, 'get base form' );
ok( !$form->field_exists('new_field'), 'no new field');
ok( $form->field_exists('optname'), 'base field exists');

use_ok( 'Form::Multiple' );

$form = Form::Multiple->new;

ok( $form, 'create multiple inheritance form' );

ok( $form->field('city'), 'field from superclass exists' );

ok( $form->field('telephone'), 'field from other superclass exists' );
