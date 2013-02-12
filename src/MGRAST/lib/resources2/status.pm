package resources2::status;

use strict;
use warnings;
no warnings('once');

use JSON;
use Conf;
use parent qw(resources2::resource);

# Override parent constructor
sub new {
    my ($class, @args) = @_;

    # Call the constructor of the parent class
    my $self = $class->SUPER::new(@args);
    
    # Add name / attributes
    $self->{name} = "status";
    return $self;
}

# resource is called without any parameters
# this method must return a description of the resource
sub info {
    my ($self) = @_;
    my $content = { 'name' => $self->name,
                            'url' => $self->cgi->url."/".$self->name,
                            'description' => "Status of asynchronous API calls",
                            'type' => 'object',
                            'documentation' => $Conf::cgi_url.'/Html/api.html#'.$self->name,
                            'requests' => [ { 'name'        => "info",
                                              'request'     => $self->cgi->url."/".$self->name,
                                              'description' => "Returns description of parameters and attributes.",
                                              'method'      => "GET" ,
                                              'type'        => "synchronous" ,  
                                              'attributes'  => "self",
                                              'parameters'  => { 'options'  => {},
                                                                 'required' => {},
                                                                 'body'     => {} }
                                            },
                                            { 'name'        => "instance",
                                              'request'     => $self->cgi->url."/".$self->name."/{TOKEN}",
                                              'description' => "Returns a single data object.",
                                              'method'      => "GET" ,
                                              'type'        => "synchronous" ,  
                                              'attributes'  => $self->attributes,
                                              'parameters'  => { 'options' => {
                                                                 'verbosity' => ['cv',
                                                                                 [['full','returns all connected metadata'],
                                                                                  ['minimal','returns only minimal information']]]
                                                                               },
                                                                 'required' => { "token" => ["string","unique process token"] },
                                                                 'body'     => {} }
                                            } ] };
    $self->return_data($content);
}

# the resource is called with a token parameter
sub instance {
    my ($self) = @_;
    
    # check token format
    my $rest = $self->rest;
    my ($token) = $rest->[0] =~ /^(\d+)$/;
    if ((! $token) && scalar(@$rest)) {
        $self->return_data( {"ERROR" => "invalid token format: " . $rest->[0]}, 400 );
    }

    my $process_status = `/bin/ps --no-heading -p $token`;
    chomp $process_status;

    my $fname = $Conf::temp.'/'.$token.'.json';

    if($process_status eq "" && !(-e $fname)) {
        $self->return_data( {"ERROR" => "token $token does not exist"}, 404 );
    }

    # return cached if exists
    $self->return_cached();

    # prepare data
    my $data = $self->prepare_data($token, $process_status, $fname);
    if($data->{status} eq "Done") {
        $self->return_data($data, undef, 1); # cache this!
    } else {
        $self->return_data($data, undef, 0); # don't cache this!
    }
}

# reformat the data into the requested output format
sub prepare_data {
    my ($self, $token, $process_status, $fname) = @_;

    my $obj = {};
    if ($process_status ne "") {
        $obj->{token} = $token;
        $obj->{status} = "Processing";
    } elsif ($process_status eq "" && $self->cgi->param('verbosity') && ($self->cgi->param('verbosity') ne 'minimal')) {
        $obj->{token} = $token;
        $obj->{status} = "Done";
    } else {
        $obj->{token} = $token;
        $obj->{status} = "Done";
        local $/;
        open my $fh, "<", $fname;
        my $json = <$fh>;
        close $fh;
        my $data = decode_json($json);
        $obj->{data} = $data;
    }

    return $obj;
}

1;