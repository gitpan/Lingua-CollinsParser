package Lingua::CollinsParser::Node;

use strict;

sub new {
  my $package = shift;
  return bless { @_ }, $package;
}

sub head {
  my $self = shift;
  return unless exists $self->{head_child};
  return $self->{children}[ $self->{head_child} ];
}

sub children {
  my $self = shift;
  return unless exists $self->{children};
  return @{ $self->{children} };
}

sub head_token   { shift->{head_token}   }
sub node_type    { shift->{node_type}    }
sub label        { shift->{label}        }
sub token        { shift->{token}        }

my %TYPE_TRANS =
  (
   #nonterminal => 'PHRASE',
   #unary => 'CLAUSE',
   leaf => 'W',
  );

sub as_xml {
  my $self = shift;

  require XML::Generator;
  my $xml = @_ ? shift : XML::Generator->new();

  my $node_type = $self->{node_type};
  $node_type = $TYPE_TRANS{$node_type} if exists $TYPE_TRANS{$node_type};

  my %attrs;
  $attrs{HEAD} = $self->{head_token} if exists $self->{head_token};
  $attrs{TAG}  = $self->{label}      if exists $self->{label};

  my @text = $self->{node_type} eq 'leaf' ? ($self->{token}) : ();

  return $xml->$node_type(
			  \%attrs,
			  map( $_->as_xml($xml), $self->children ),
			  @text,
			 );
}

1;
__END__

=head1 NAME

Lingua::CollinsParser::Node - Syntax tree node

=head1 SYNOPSIS

  use Lingua::CollinsParser;
  my $p = Lingua::CollinsParser->new();
  ...
  my $node = $p->parse_sentence(\@words, \@tags);
  
  my $head = $node->head;
  my @children = $node->children;
  print $node->as_xml;

=head1 DESCRIPTION

This class represents a node in a syntax tree generated by C<<
Lingua::CollinsParser->parse_sentence >>.  Each node may contain zero
or more child nodes - thus the tree structure.  This class provides no
methods for altering the tree structure, so the trees are effectively
read-only objects.

=head1 METHODS

The following methods are available in the
C<Lingua::CollinsParser::Node> class:

=over 4

=item new(...)

Creates a new C<Lingua::CollinsParser::Node> object and returns it.
For initialization, C<new()> accepts a list of key-value pairs
corresponding to the data fields C<children>, C<head_token>,
C<head_child>, C<node_type>, C<label>, and C<token>.

=item head()

Returns the head child node of this node, or C<undef> if this node has
no head.

=item children()

In list context, returns the child nodes of this node.  In scalar
context, returns the number of child nodes.

=item token()

Returns the token associated with this node, or C<undef> if this node
is not associated with a token (i.e. if this node isn't a leaf).

=item head_token()

Returns the token representing the head of this node.  This is
equivalent to following C<head()> to a leaf node and then returning
C<token()>, but faster.

=item node_type()

Returns the type of this node.  The current allowable values are
C<leaf>, C<nonterminal>, and C<unary>; these values may change in
future versions.

=item label()

For leaf nodes, returns the part-of-speech associated with this node.
For other nodes, returns the syntactic label of the constituent
represented by this node.

=item as_xml()

Returns a string representing this node as XML.  The exact names of
the tags in the output are subject to change in future versions.

=back

=head1 AUTHOR

Ken Williams, ken.williams@thomson.com

=cut