requires 'Moose';
requires 'JSON::MaybeXS';
requires 'MooseX::StrictConstructor';
requires 'HTTP::Request::StreamingUpload';

on 'test' => sub {
    requires 'WWW::Mechanize';
};
