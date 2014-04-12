package Mojo::YR;

=head1 NAME

Mojo::YR - Get weather information from yr.no

=head1 DESCRIPTION

L<Mojo::YR> is an (a)synchronous weather data fetcher for the L<Mojolicious>
framework. The backend for weather data is L<http://yr.no>.

Look at the resources below for mere information about the API:

=over 4

=item * L<http://api.yr.no/weatherapi/documentation>

=item * L<http://api.yr.no/weatherapi/locationforecast/1.8/documentation>

=item * L<http://api.yr.no/weatherapi/textforecast/1.6/documentation>

=back

=head1 SYNOPSIS

  use Mojo::YR;
  my $yr = Mojo::YR->new;

  # Fetch location_forecast ==========================================
  my $now = $self->location_forecast->find('pointData > time')->first;
  my $temp = $now->find('temperature');

  warn "$temp->{value} $temp->{unit}";

  # Fetch text_forecast ==============================================
  my $today = $self->text_forecast->children('time')->first;
  my $hordaland = $today->find('area[name="Hordaland"]')->first;

  warn $hordaland->find('header')->text;
  warn $hordaland->find('in')->text; # "in" holds the forecast text

=cut

use Mojo::Base -base;
use Mojo::UserAgent;

=head2 url_map

  $hash_ref = $self->url_map;

Returns the addresses used to fetch data.

Note: These will always be what you expect. If the resources get changed in
the future, a C<version()> attribute will be added to this class to ensure
you always get the same URL map.

Default:

  {
    location_forecast => 'http://api.yr.no/weatherapi/locationforecast/1.8/',
    text_forecast => 'http://api.yr.no/weatherapi/textforecast/1.6/',
  };

=cut

has url_map => sub {
  my $self = shift;

  return {
    location_forecast => 'http://api.yr.no/weatherapi/locationforecast/1.8/',
    text_forecast => 'http://api.yr.no/weatherapi/textforecast/1.6/',
  };
};

has _ua => sub {
  Mojo::UserAgent->new->max_redirects(2)->ioloop(Mojo::IOLoop->singleton);
};

=head1 METHODS

=head2 location_forecast

  $self = $self->location_forecast([$latitude, $longitude], sub { my($self, $err, $dom) = @_; ... });
  $self = $self->location_forecast(\%args, sub { my($self, $err, $dom) = @_; ... });
  $dom = $self->location_forecast([$latitude, $longitude]);
  $dom = $self->location_forecast(\%args);

Used to fetch
L<weather forecast for a specified place|http://api.yr.no/weatherapi/locationforecast/1.8/documentation>.

C<%args> is required (unless C<[$latitude,$longitude]> is given):

  {
    latitude => $num,
    longitude => $num,
  }

C<$dom> is a L<Mojo::DOM> object you can use to query the result.
See L</SYNOPSIS> for example.

=cut

sub location_forecast {
  my($self, $args, $cb) = @_;
  my $url = Mojo::URL->new($self->url_map->{location_forecast});

  if(ref $args eq 'ARRAY') {
    $args = { latitude => $args->[0], longitude => $args->[1] };
  }
  if(2 != grep { defined $args->{$_} } qw( latitude longitude )) {
    return $self->$cb('latitude and/or longitude is missing', undef);
  }

  $url->query([
    lon => $args->{longitude},
    lat => $args->{latitude},
  ]);

  $self->_run_request($url, $cb);
}

=head2 text_forecast

  $dom = $self->text_forecast(\%args);
  $self = $self->text_forecast(\%args, sub { my($self, $err, $dom) = @_; ... });

Used to fetch
L<textual weather forecast for all parts of the country|http://api.yr.no/weatherapi/textforecast/1.6/documentation>.

C<%args> is optional and has these default values:

  {
    forecast => 'land',
    language => 'nb',
  }

C<$dom> is a L<Mojo::DOM> object you can use to query the result.
See L</SYNOPSIS> for example.

=cut

sub text_forecast {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = shift || {};
  my $url = Mojo::URL->new($self->url_map->{text_forecast});

  $url->query([
    forecast => $args->{forecast} || 'land',
    language => $args->{language} || 'nb',
  ]);

  $self->_run_request($url, $cb);
}

sub _run_request {
  my($self, $url, $cb) = @_;
  my $delay = $cb ? undef : $self->_ua->ioloop->delay;

  $cb = $delay->begin if $delay;

  Scalar::Util::weaken($self);
  $self->_ua->get(
    $url,
    sub {
      my($ua, $tx) = @_;
      my $err = $tx->error;

      return $self->$cb($err, undef) if $err;
      return $self->$cb('', $tx->res->dom->children->first); # <weather> is the first element. don't want that
    },
  );

  return $self unless $delay;
  my @res = $delay->wait;
  die $res[0] if $res[0];
  return $res[1];
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
