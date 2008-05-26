package Devel::REPL::Plugin::LexEnv;

use Moose::Role;
use namespace::clean -except => [ 'meta' ];
use Lexical::Persistence;

with 'Devel::REPL::Plugin::FindVariable';

has 'lexical_environment' => (
  isa => 'Lexical::Persistence',
  is => 'rw',
  required => 1,
  lazy => 1,
  default => sub { Lexical::Persistence->new }
);

has '_hints' => (
  isa => "ArrayRef",
  is => "rw",
  predicate => '_has_hints',
);

around 'mangle_line' => sub {
  my $orig = shift;
  my ($self, @rest) = @_;
  my $line = $self->$orig(@rest);
  my $lp = $self->lexical_environment;
  # Collate my declarations for all LP context vars then add '';
  # so an empty statement doesn't return anything (with a no warnings
  # to prevent "Useless use ..." warning)
  return join('',
    'BEGIN { if ( $_REPL->_has_hints ) { ( $^H, %^H ) = @{ $_REPL->_hints } } }',
    ( map { "my $_;\n" } keys %{$lp->get_context('_')} ),
    qq{{ no warnings 'void'; ''; }\n},
    $line,
    '; BEGIN { $_REPL->_hints([ $^H, %^H ]) }',
  );
};

around 'execute' => sub {
  my $orig = shift;
  my ($self, $to_exec, @rest) = @_;
  my $wrapped = $self->lexical_environment->wrap($to_exec);
  return $self->$orig($wrapped, @rest);
};

around 'find_variable' => sub {
  my $orig = shift;
  my ($self, $name) = @_;

  return \( $self->lexical_environment->get_context('_')->{$name} )
    if exists $self->lexical_environment->get_context('_')->{$name};

  return $orig->(@_);
};

1;
