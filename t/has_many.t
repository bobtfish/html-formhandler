use strict;
use warnings;
use Test::More tests => 21;

use_ok( 'HTML::FormHandler::Field::Repeatable' );
use_ok( 'HTML::FormHandler::Field::Repeatable::Instance' );

{
   package Repeatable::Form;
   use HTML::FormHandler::Moose;
   extends 'HTML::FormHandler';

   has_field 'my_test';
   has_field 'addresses' => ( type => 'Repeatable', auto_id => 1 );
   has_field 'addresses.street';
   has_field 'addresses.city';
   has_field 'addresses.country';

}

my $form = Repeatable::Form->new;

ok( $form, 'created hasmany form');

$form = Repeatable::Form->new;
ok( $form->field('addresses')->has_fields, 'created form again with fields');

# empty form, creating new record 
$form->process( params => {} );
ok( $form->field('addresses')->field('0')->field('city'), 'empty field exists' );

my $init_object = {
   addresses => [
      {
         street => 'First Street',
         city => 'Prime City',
         country => 'Utopia',
         id => 0,
      },
      {
         street => 'Second Street',
         city => 'Secondary City',
         country => 'Graustark',
         id => 1,
      },
      {
         street => 'Third Street',
         city => 'Tertiary City',
         country => 'Atlantis',
         id => 2,
      }
   ]
};

$form = Repeatable::Form->new( init_object => $init_object ); 
ok( $form, 'created form from initial object' );

is_deeply( $form->values, $init_object, 'get values back out' ); 
is_deeply( $form->field('addresses')->value, $init_object->{addresses}, 'hasmany field value');
is_deeply( $form->field('addresses')->field('0')->value, $init_object->{addresses}->[0],
    'instance field value' );
is( $form->field('addresses')->field('0')->field('city')->value, 'Prime City', 
    'compound subfield value');


my $fif = {
   'addresses.0.street' => 'First Street',
   'addresses.0.city' => 'Prime City',
   'addresses.0.country' => 'Utopia',
   'addresses.0.id' => '0',
   'addresses.1.street' => 'Second Street',
   'addresses.1.city' => 'Secondary City',
   'addresses.1.country' => 'Graustark',
   'addresses.1.id' => '1',
   'addresses.2.street' => 'Third Street',
   'addresses.2.city' => 'Tertiary City',
   'addresses.2.country' => 'Atlantis',
   'addresses.2.id' => '2',
   'my_test' => '',
};

is_deeply( $form->fif, $fif, 'get fill in form');
$fif->{'addresses.0.city'} = 'Primary City';
$fif->{'addresses.2.country'} = 'Grand Fenwick';
delete $fif->{my_test};

$form->clear;
$form->process($fif);
$fif->{my_test} = '';
is_deeply( $form->fif, $fif, 'still get right fif');
$init_object->{addresses}->[0]->{city} = 'Primary City';
$init_object->{addresses}->[2]->{country} = 'Grand Fenwick';
is_deeply( $form->values, $init_object, 'still get right values');

$fif = {
   'addresses.0.street' => 'First Street',
   'addresses.0.city' => 'Prime City',
   'addresses.0.country' => 'Utopia',
   'addresses.0.id' => '0',
   'addresses.2.street' => 'Third Street',
   'addresses.2.city' => 'Tertiary City',
   'addresses.2.country' => 'Atlantis',
   'addresses.2.id' => '2',
};

$form->process($fif);

ok( $form->validated, 'form validated' );
is( $form->field('addresses')->num_fields, 2, 'right number of fields');

$fif = {
   'addresses.0.street' => 'Main Street',
   'addresses.0.city' => 'Prime City',
   'addresses.0.country' => 'Utopia',
   'addresses.0.id' => '0',
};

ok( $form->process($fif), 'process a single repeatable element');
is( $form->field('addresses')->field('0')->field('street')->value, 'Main Street', 'get value');

my $values = {
   'addresses' => [
      {
         'city' => 'Prime City',
         'country' => 'Utopia',
         'id' => 0,
         'street' => 'Main Street',
      }
   ]
};
is_deeply( $form->values, $values, 'get right values' );

my $no_repeat = {
   my_test => 'test'
};
$form->process( $no_repeat );
is_deeply( $form->value()->{addresses}, [],  'Addresses deleted not in params' );

$form->process({});
ok( exists $form->value->{addresses}[0], 'Addresses are back' );
$form->clear_init_object;
$form->process( { my_test => 'test' } );
is_deeply( $form->value()->{addresses}, [], 'Addresses deleted' );

