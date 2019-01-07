=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::IO::Adaptor::VCFAdaptor;

use strict;
use warnings;

use EnsEMBL::Web::Utils::FormatText qw(date_format);
use File::Path qw(make_path);

use Vcf;
my $DEBUG = 0;

my $snpCode = {
    'AG' => 'R',
    'GA' => 'R',
    'AC' => 'M',
    'CA' => 'M',
    'AT' => 'W',
    'TA' => 'W',
    'CT' => 'Y',
    'TC' => 'Y',
    'CG' => 'S',
    'GC' => 'S',
    'TG' => 'K',
    'GT' => 'K'
};

sub new {
  my ($class, $url, $hub) = @_;
  my $self = bless {
    _cache => {},
    _url => $url,
    _hub => $hub,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };

sub hub { return $_[0]->{'_hub'} };

sub snp_code {
    my ($self, $allele) = @_;
    
    return $snpCode->{$allele};
}


sub fetch_variations {
  my ($self, $chr, $s, $e) = @_;

  if (!$self->{_cache}->{features} || (ref $self->{_cache}->{features} eq 'ARRAY' && !@{$self->{_cache}->{features}})){
    my @features;
    delete $self->{_cache}->{features};

    ## Eagle fix - tabix will want to write the downloaded index file to 
    ## the current working directory. By default this is '/'
    my $time = date_format(time(), '%y-%m-%d'); 
    my $path = $SiteDefs::ENSEMBL_USERDATA_DIR."/temporary/vcf_tabix/$time/";
    make_path($path);

    foreach my $chr_name ($chr,"chr$chr") { # maybe UCSC-type names?
      my %args = ( 
        region  => "$chr_name:$s-$e",
        file    => $self->url,
        tabix   => $self->hub->species_defs->TABIX,
        tmp_dir => $path,
      );

      my $vcf = Vcf->new(%args);

      ## Eagle fix - this should be called before calling $vcf->next_line to avoid
      ## header line error messages, but require latest vcftools 
      $vcf->parse_header();

      while (my $line=$vcf->next_line()) {
        my $x=$vcf->next_data_hash($line);
        push @features, $x;
      }
      last if(@features);
    }
    $self->{_cache}->{features} = \@features;
  }
  return $self->{_cache}->{features};
}

1;
