use Test::More;
use lib 't/lib';

BEGIN {
   eval "use DBIx::Class";
   plan skip_all => 'DBIX::Class required' if $@;
   plan tests => 8;
}

use_ok( 'BookDB::Form::Book');

use BookDB::Schema::DB;

my $schema = BookDB::Schema::DB->connect('dbi:SQLite:t/db/book.db');
ok($schema, 'get db schema');

my $duplicate_isbn = $schema->resultset('Book')->find(1)->isbn;

my $form = BookDB::Form::Book->new(item_id => undef, schema => $schema);

ok( !$form->process, 'Empty data' );

# This is munging up the equivalent of param data from a form
my $params = {
    'title' => 'How to Test Perl Form Processors',
    'author' => 'I.M. Author',
    'isbn'   => $duplicate_isbn, 
    'publisher' => 'EreWhon Publishing',
};

ok( !$form->process( $params ), 'duplicate isbn fails validation' );

my @errors = $form->field('isbn')->errors;

is( $errors[0], 'Duplicate value for ISBN', 'error message for duplicate');

{
   package My::Form;
   use Moose;
   extends 'HTML::FormHandler::Model::DBIC';

   has '+item_class' => ( default => 'Book' );

   sub field_list {
        [
            title     => {
               type => 'Text',
               required => 1,
            },
            author    => 'Text',
            isbn => {
               type => 'Text',
               unique => 1,
               unique_message => 'Duplicate ISBN number',
            }
        ]
   }
}

my $form2 = My::Form->new( item_id => undef, schema => $schema );

ok( ! $form2->process( $params ), 'duplicate isbn again' );

@errors = $form2->field('isbn')->errors;

is( $errors[0], 'Duplicate ISBN number', 'field error message for duplicate');

my $book = $schema->resultset('Book')->find(1);
my $form3 = My::Form->new( item_id => [ $book->id ], schema => $schema );
ok( $form3->process( $params ), 'Updating works' );


