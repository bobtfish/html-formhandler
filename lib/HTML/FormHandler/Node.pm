package HTML::FormHandler::Node;

use Moose;
use Carp;
use UNIVERSAL::require;
use Class::Inspector;

=head1 NAME

HTML::FormHandler::Node - class to build field array

=head1 SYNOPSIS

This is a class which is embedded in both Forms and Fields, which
represents a node in a tree of fields.  

=head2 parent

a HTML::FormHandler::Field. This is not defined in top-level
fields (those contained in a form).

=cut

has 'parent' => ( isa => 'HTML::FormHandler::Field', is => 'rw' );

=head2 form_name

The name of the containing form

=cut

has 'form_name' => ( isa => 'Str', is => 'rw' );

=head2 fields

The field definitions as built from the field_list and the 'has_field'
declarations. This is a MooseX::AttributeHelpers::Collection::Array, 
and provides clear_fields, add_field, remove_last_field, num_fields,
has_fields, and set_field_at methods.

The methods for dealing with fields are delegated to the containing
form or field.

=cut

has 'field_list' => ( isa => 'HashRef|Undef', is => 'rw', default => sub { {} } );
has 'meta_field_list' => ( is => 'rw', isa => 'ArrayRef|Undef', 
   predicate => 'has_meta_field_list' );
has 'is_top_level' => ( isa => 'Bool', is => 'rw' );
has 'field_counter' => ( isa => 'Int', is => 'rw', default => 1 );
has 'language_handle' => ( is      => 'rw' );


has 'fields' => (
   metaclass  => 'Collection::Array',
   isa        => 'ArrayRef[HTML::FormHandler::Field]',
   is         => 'rw',
   default    => sub { [] },
   auto_deref => 1,
   provides   => {
      clear => 'clear_fields',
      push  => 'add_field',
      pop   => 'remove_last_field',
      count => 'num_fields',
      empty => 'has_fields',
      set   => 'set_field_at',
   }
);

has 'field_name_space' => (
   isa     => 'Str|Undef',
   is      => 'rw',
   default => '',
);

=head2 build_fields

This parses the field lists and creates the individual
field objects.  It calls the make_field() method for each field.
This is called by the BUILD method. Users don't need to call this.

=cut

sub build_fields
{
   my $self = shift;

   my $meta_flist = $self->meta_field_list;
   $self->_build_fields( $meta_flist, 0 ) if $meta_flist; 
   if( $self->can('field_list') && $self->field_list )
   {
      my $flist = $self->field_list;
      $self->_build_fields( $flist->{'required'}, 1 ) if $flist->{'required'}; 
      $self->_build_fields( $flist->{'optional'}, 0 ) if $flist->{'optional'};
      $self->_build_fields( $flist->{'fields'}, 0 )   if $flist->{'fields'};
      $self->_build_fields( $flist->{'auto_required'}, 1, 'auto' ) 
                                                 if $flist->{'auto_required'};
      $self->_build_fields( $flist->{'auto_optional'}, 0, 'auto' ) 
                                                 if $flist->{'auto_optional'};
   }
   return unless $self->has_fields;
   # get highest order number
   my $order = 0;
   foreach my $field ( $self->fields)
   {
      $order++ if $field->order > $order;
   }
   $order++;
   # number all unordered fields
   foreach my $field ( $self->fields )
   {
      $field->order( $order ) unless $field->order;
      $order++;
      # collect child references in parent field
      if( $field->parent && !$field->parent_field )
      {
         my $parent = $self->field($field->parent);
         die "Parent field for " . $field->name . "not found" unless $parent;
         $parent->add_field($field);
         $field->parent_field($parent);
      }
   }

}


sub _build_fields
{
   my ( $self, $fields, $required, $auto ) = @_;

   return unless $fields;
   my $field;
   my $name;
   my $type;
   if ($auto)    # an auto array of fields
   {
      foreach $name (@$fields)
      {
         $type = $self->guess_field_type($name);
         croak "Could not guess field type for field '$name'" unless $type;
         $self->_set_field( $name, $type, $required );
      }
   }
   elsif ( ref($fields) eq 'ARRAY' )    # an array of fields
   {
      while (@$fields)
      {
         $name = shift @$fields;
         $type = shift @$fields;
         $self->_set_field( $name, $type, $required );
      }
   }
   else                                 # a hashref of fields
   {
      while ( ( $name, $type ) = each %$fields )
      {
         $self->_set_field( $name, $type, $required );
      }
   }
   return;
}

sub _set_field
{
   my ( $self, $name, $type, $required ) = @_;

   my $field = $self->make_field( $name, $type );
   return unless $field;
   $field->required($required) unless ( $field->required == 1 );
   my $index = $self->field_index($field->full_name);
   if( defined $index )
      { $self->set_field_at($index, $field); }
   else
      { $self->add_field($field); }
}

=head2 make_field

    $field = $form->make_field( $name, $type );

Maps the field type to a field class, creates a field object and
and returns it.

The "$name" parameter is the field's name (e.g. first_name, age).

The second parameter is either a scalar which is the field's type
string, or a hashref with a 'type' key containing the field's type.

=cut

sub make_field
{
   my ( $self, $name, $attr ) = @_;

   $attr = { type => $attr } unless ref $attr eq 'HASH';
   my $type = $attr->{type} ||= 'Text';

   # TODO what about fields with fields? namespace from where?
   my $class =
        $type =~ s/^\+//
      ? $self->field_name_space
         ? $self->field_name_space . "::" . $type
         : $type
      : 'HTML::FormHandler::Field::' . $type;
      
   $class->require 
      or die "Could not load field class '$type' $class for field '$name'"
      if !Class::Inspector->loaded($class);

   # Add field name and reference to form 
   $attr->{name} = $name;
   $attr->{language_handle} = $self->language_handle;
   $attr->{is_top_level} = $self->is_top_level;
   unless ( $self->parent ) # only for top-level nodes
   {
      $attr->{form} = $self;
      if( $name =~ /\./ )
      {
         my @names = split /\./, $name;
         my $simple_name = pop @names;
         my $parent = pop @names;
         $attr->{parent} = $parent;
         $attr->{name} = $simple_name; 
      }
   }
   elsif( $self->isa('HTML::FormHandler::Field') )
   {
      $attr->{parent} = $self->name;
      $attr->{parent_field} = $self;
      $attr->{form} = $self->form if $self->form;
   }
   my $field = $class->new( %{$attr} );
   return $field;
}

=head2 field_index

Convenience function for use with 'set_field_at'.

=cut 

sub field_index
{
   my ( $self, $full_name ) = @_;
   my $index = 0;
   for my $field ( $self->fields )
   {
      return $index if $field->full_name eq $full_name;
      $index++;
   }
   return;
}

sub field
{
   my ( $self, $name, $no_die ) = @_;

   for my $field ( $self->fields )
   {
      return $field if ($field->full_name eq $name || $field->name eq $name);
   }
   return if $no_die;
   croak "Field '$name' not found in '$self'";
}

sub fields_validate
{
   my $self = shift;
   # validate all fields
   foreach my $field ( $self->fields )
   {
      next if $field->clear;    # Skip validation
      # parent fields will call validation for children
      next if $field->parent_field && $self->isa('HTML::FormHandler'); 
      # Validate each field and "inflate" input -> value.
      $field->validate_field;  # this calls the field's 'validate' routine
      next unless $field->has_value && defined $field->value; 
      # these methods have access to the inflated values
      my $form = $self if $self->isa('HTML::FormHandler');
      $form = $self->form if ( $self->isa('HTML::Field') && self->form );
      my $method = $field->validate_meth;
      next unless $form && $form->can($method);
      $form->$method($field);
   }
}

no Moose;
1;
