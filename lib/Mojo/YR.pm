package Mojo::YR;

=head1 NAME

Mojo::YR - Get weather information from yr.no

=head1 DESCRIPTION

=head1 SYNOPSIS

  use Mojo::YR;
  my $yr = Mojo::YR->new;

=cut

use Mojo::Base -base;
use Mojo::UserAgent;

has _ua => sub {
  my $ua = Mojo::UserAgent->new;

  $ua->max_redirects(2);
  $ua->ioloop(Mojo::IOLoop->singleton);
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

C<$dom> is a L<Mojo::DOM> object you can use to query the result:

  my $now = $self->location_forecast->find('pointData > time')->first;
  my $temp = $now->find('temperature');

  warn "$temp->{value} $temp->{unit}";

=cut

sub location_forecast {
  my($self, $args, $cb) = @_;

  if(ref $args eq 'ARRAY') {
    $args = { latitude => $args->[0], longitude => $args->[1] };
  }
  if(2 != grep { defined $args->{$_} } qw( latitude longitude )) {
    return $self->$cb('latitude and/or longitude is missing', undef);
  }

  $self->_run_request(
    $self->url_for(
      location_forecast => [
        lon => $args->{longitude},
        lat => $args->{latitude},
      ],
    ),
    $cb,
  );
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

C<$dom> is a L<Mojo::DOM> object you can use to query the result:

  my $today = $self->text_forecast->children('time')->first;
  my $hordaland = $today->find('area[name="Hordaland"]')->first;

  warn $hordaland->find('header')->text;
  warn $hordaland->find('in')->text; # "in" holds the forecast text

=cut

sub text_forecast {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = shift || {};

  $self->_run_request(
    $self->url_for(
      text_forecast => [
        forecast => $args->{forecast} || 'land',
        language => $args->{language} || 'nb',
      ],
    ),
    $cb,
  );
}

=head2 url_for

  $url = $self->url_for($type, \@query_params);

Used to create a L<Mojo::URL> object. Supported types are "location_forecast"
and "text_forecast".

=cut

sub url_for {
  my($self, $type, $query_params) = @_;
  my $url;

  if($type eq 'location_forecast') {
    $url = Mojo::URL->new('http://api.yr.no/weatherapi/locationforecast/1.8/');
  }
  elsif($type eq 'text_forecast') {
    $url = Mojo::URL->new('http://api.yr.no/weatherapi/textforecast/1.6/');
  }
  else {
    die "Invalid type: $type";
  }

  $url->query($query_params);
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

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
