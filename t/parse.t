#!/usr/bin/env perl

use strict;
use warnings;
use feature 'postderef';

use Test::More;
use Test::Exception;
use File::Find;
use Path::Class::File;
use JSON::MaybeXS;

my @files;

if (@ARGV) {
  @files = @ARGV;
} else {
  File::Find::find({wanted => \&wanted}, 't/azure-examples/');
  sub wanted {
      /^azuredeploy\.json\z/s
      && push @files, $File::Find::name;
  }
}

use AzureARM;

foreach my $file_name (@files) {
  diag($file_name);
  my $file = Path::Class::File->new($file_name);
  my $content = $file->slurp;
  my $origin = decode_json($content);
  my $arm;

  lives_ok sub { $arm = AzureARM->from_hashref($origin) }, "Parsed $file";

  cmp_ok($arm->VariableCount,  '==', keys %{ $origin->{ variables }  // {} }, 'Got the same number of variables');
  cmp_ok($arm->ParameterCount, '==', keys %{ $origin->{ parameters } // {} }, 'Got the same number of parameters');
  cmp_ok($arm->OutputCount,    '==', keys %{ $origin->{ outputs }    // {} }, 'Got the same number of outputs');
  cmp_ok($arm->ResourceCount,  '==', @{ $origin->{ resources } }, 'Got the same number of resources');

  my $generated = $arm->as_hashref;

  cmp_ok($generated->{ resources }->@*, '==', $origin->{ resources }->@*, 'Got the same resources once parsed');
  for (my $i=0; $i <= $generated->{ resources }->@*; $i++) {
    my $generated_r = $generated->{ resources }->[$i];
    my $origin_r    = $origin->{ resources }->[$i];

use Data::Dumper;
print Dumper($generated_r, $origin_r);

    is_deeply($generated_r, $origin_r);
  }

  is_deeply($generated->{ parameters }, $origin->{ parameters }, 'Got the same parameters once parsed');

  cmp_ok(keys %{ $generated->{ outputs } // {} }, '==', keys %{ $origin->{ outputs } // {} }, 'Got the same number of outputs');
  foreach my $out (keys $generated->{ outputs }->%*) {
    equiv_expression($generated->{ outputs }->{ $out }->{ value }, $origin->{ outputs }->{ $out }->{ value }, "Output $out value is equivalent once parsed");
    cmp_ok($generated->{ outputs }->{ $out }->{ type }, 'eq', $origin->{ outputs }->{ $out }->{ type }, "Output $out type is equivalent once parsed");
  }

  cmp_ok(keys %{ $generated->{ variables } // {} }, '==', keys %{ $origin->{ variables } // {} }, 'Got the same number of variables');
  foreach my $var (keys $generated->{ variables }->%*) {
    equiv_expression($generated->{ variables }->{ $var }, $origin->{ variables }->{ $var }, "Var $var is equivalent once parsed");
  }
  #$arm->variables
}

sub equiv_expression {
  my ($expr1, $expr2, $text) = @_;
  $expr1 =~ s/\s//g;
  $expr2 =~ s/\s//g;
  cmp_ok($expr1, 'eq', $expr2, $text); 
}

done_testing;
