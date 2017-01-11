requires 'Moose';
requires 'JSON::MaybeXS';
requires 'MooseX::StrictConstructor';
requires 'HTTP::Request::StreamingUpload';
requires 'Pod::Markdown';

on 'test' => sub {
    requires 'WWW::Mechanize';
};
