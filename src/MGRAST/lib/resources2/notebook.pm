package resources2::notebook;

use strict;
use warnings;
no warnings('once');
use POSIX qw(strftime);
use MIME::Base64;
use Auth;

use Conf;
use parent qw(resources2::resource);

# Override parent constructor
sub new {
    my ($class, @args) = @_;

    # Call the constructor of the parent class
    my $self = $class->SUPER::new(@args);
    
    # get notebook admin token
    my $nb_token = undef;
    if ($Conf::nb_admin_user && $Conf::nb_admin_pswd) {
        my $key = encode_base64($Conf::nb_admin_user.':'.$Conf::nb_admin_pswd);
        $nb_token = Auth::globus_token($key)->{access_token};
    }
    
    # Add name / attributes
    $self->{name}       = "notebook";
    $self->{nb_token}   = $nb_token;
    $self->{attributes} = { "id"       => [ 'string', 'unique shock identifier' ],
                            "name"     => [ 'string', 'human readable identifier' ],
                            "nbid"     => [ 'string', 'ipynb identifier - stable across different versions'],
                            "notebook" => [ 'object', 'notebook object in JSON format' ],
                            "created"  => [ 'date', 'time the object was first created' ],
                            "version"  => [ 'integer', 'version of the object' ],
                            "url"      => [ 'uri', 'resource location of this object instance' ],
                            "status"   => [ 'cv', [['public', 'notebook is public'],
           										   ['private', 'notebook is private']] ],
           					"permission" => [ 'cv', [['view', 'notebook is viewable only'],
                                 					 ['edit', 'notebook is editable']] ],
                            "description" => [ 'string', 'descriptive text about notebook' ],
                          };
    return $self;
}


# resource is called without any parameters
# this method must return a description of the resource
sub info {
    my ($self) = @_;
    my $content = { 'name'          => $self->name,
                    'url'           => $self->cgi->url."/".$self->name,
                    'description'   => "A notebook is a JSON structure describing the contents of an ipython session.",
                    'type'          => 'object',
                    'documentation' => '',
                    'requests'      => [ { 'name'        => "info",
            				               'request'     => $self->cgi->url."/".$self->name,
            				               'description' => "Returns description of parameters and attributes.",
            				               'method'      => "GET",
            				               'type'        => "synchronous",  
            				               'attributes'  => "self",
            				               'parameters'  => { 'options'  => {},
            							                      'required' => {},
            							                      'body'     => {} } },
                                         { 'name'        => "query",
            				               'request'     => $self->cgi->url."/".$self->name,
            				               'description' => "Returns a set of data matching the query criteria.",
            				               'method'      => "GET",
            				               'type'        => "synchronous",  
            				               'attributes'  => { "next"   => ["uri", "link to the previous set or null if this is the first set"],
                       							              "prev"   => ["uri", "link to the next set or null if this is the last set"],
                       							              "order"  => ["string", "name of the attribute the returned data is ordered by"],
                       							              "data"   => ["list", ["object", [$self->attributes, "list of the project objects"]]],
                       							              "limit"  => ["integer", "maximum number of data items returned, default is 10"],
                       							              "total_count" => ["integer", "total number of available data items"],
                       							              "offset" => ["integer", "zero based index of the first returned data item"] },
            				               'parameters'  => { 'options'  => { 'type' => ['string', 'notebook type'],
            				                                                  'verbosity' => ['cv', [['minimal', 'returns notebook attributes'],
                       												                                 ['full', 'returns notebook attributes and object']]],
                       									                      'limit'     => ['integer', 'maximum number of items requested'],
                       									                      'offset'    => ['integer', 'zero based index of the first data object to be returned'],
                       									                      'order'     => ['cv', [['id' , 'return data objects ordered by id'],
                       												                                 ['name' , 'return data objects ordered by name']]]
                       												        },
            							                      'required' => {},
            							                      'body'     => {} } },
                                         { 'name'        => "instance",
            				               'request'     => $self->cgi->url."/".$self->name."/{ID}",
            				               'description' => "Returns a single data object.",
            				               'method'      => "GET",
            				               'type'        => "synchronous",  
            				               'attributes'  => $self->attributes,
            				               'parameters'  => { 'options'  => { 'type' => ['string', 'notebook type'],
            				                                                  'verbosity' => ['cv', [['minimal', 'returns notebook attributes'],
                       												                                 ['full', 'returns notebook attributes and object']]]
                       												        },
            							                      'required' => { "id" => ["string", "unique shock object identifier"] },
            							                      'body'     => {} } },
            							 { 'name'        => "clone",
             				               'request'     => $self->cgi->url."/".$self->name."/{ID}/{NBID}",
             				               'description' => "Clones a data object with new notebook id and returns it.",
             				               'method'      => "GET",
             				               'type'        => "synchronous",  
             				               'attributes'  => $self->attributes,
             				               'parameters'  => { 'options'  => { 'verbosity' => ['cv', [['minimal', 'returns notebook attributes'],
                          												                             ['full', 'returns notebook attributes and object']]],
                          												      'name'      => ['string', "name of new cloned notebook"]
                          											        },
             							                      'required' => { "id"   => ["string", "unique shock object identifier"],
             							                                      "nbid" => ["string", "unique notebook object identifier"] },
             							                      'body'     => {} } },
             							 { 'name'        => "delete",
              				               'request'     => $self->cgi->url."/".$self->name."/delete/{NBID}",
              				               'description' => "Flags notebook as deleted.",
              				               'method'      => "GET",
              				               'type'        => "synchronous",  
              				               'attributes'  => $self->attributes,
              				               'parameters'  => { 'options'  => {},
              							                      'required' => { "id" => ["string", "unique notebook object identifier"] },
              							                      'body'     => {} } },
             							 { 'name'        => "upload",
             				               'request'     => $self->cgi->url."/".$self->name."/upload",
             				               'description' => "Upload a notebook to shock.",
             				               'method'      => "POST",
             				               'type'        => "synchronous",  
             				               'attributes'  => $self->attributes,
             				               'parameters'  => { 'options'  => {},
             							                      'required' => {},
             							                      'body'     => { "ipynb" => ["file", ".pynb file in JSON format"] } } },
            						   ]
                  };
    $self->return_data($content);
}

# the resource is called with an id parameter
sub instance {
    my ($self) = @_;

    # possible upload
    if (($self->rest->[0] eq 'upload') && ($self->method eq 'POST')) {
        $self->upload_notebook();
    }
    
    # possible delete
    if (($self->rest->[0] eq 'delete') && (@{$self->rest} > 1)) {
        $self->delete_notebook($self->rest->[1]);
    }
    
    # get data
    my $data = [];
    my $id   = $self->rest->[0];
    my $node = $self->get_shock_node($id, $self->shock_auth());
    unless ($node) {
        $self->return_data( {"ERROR" => "id $id does not exists"}, 404 );
    }

    # clone node if requested (update shock attributes and ipynb metadata)
    if (@{$self->rest} > 1) {
        my $clone = $self->clone_notebook($node, $self->rest->[1], $self->cgi->param('name'));
        $data = $self->prepare_data( [$clone] );
    } else {
        $data = $self->prepare_data( [$node] );
    }
    
    $self->return_data($data->[0]);
}

# the resource is called without an id parameter, but with at least one query parameter
sub query {
    my ($self) = @_;
 
    # get all items the user has access to
    my $attr  = {};
    if ($self->cgi->param('type')) {
        $attr->{type} = $self->cgi->param('type');
    }
    my $nodes = $self->get_shock_query('ipynb', $attr, $self->shock_auth());
    my $total = scalar @$nodes;
 
    # check limit
    my $limit  = defined($self->cgi->param('limit')) ? $self->cgi->param('limit') : 10;
    my $offset = $self->cgi->param('offset') || 0;
    my $order  = $self->cgi->param('order')  || "id";
    @$nodes = sort { $a->{$order} cmp $b->{$order} } @$nodes;
    $limit  = (($limit == 0) || ($limit > scalar(@$nodes))) ? scalar(@$nodes) : $limit;
    @$nodes = @$nodes[$offset..($offset+$limit-1)];

    # prepare data to the correct output format
    my $data = $self->prepare_data($nodes);

    # check for pagination
    $data = $self->check_pagination($data, $total, $limit);

    $self->return_data($data);
}

# reformat the data into the requested output format
sub prepare_data {
    my ($self, $data) = @_;
    
    my $objects = [];
    foreach my $node (@$data) {
        my $url = $self->cgi->url;
        my $obj = {};
        $obj->{id}   = $node->{id};
        $obj->{url}  = $url.'/notebook/'.$obj->{id};
        $obj->{name} = $node->{attributes}{name} || 'Untitled';
        $obj->{nbid} = $node->{attributes}{nbid};
        $obj->{version} = 1;
        $obj->{created} = $node->{attributes}{created};
	    $obj->{status}  = (exists $node->{attributes}{deleted}) ? 'deleted' : ($self->token ? 'private' : 'public');
	    $obj->{permission}  = $node->{attributes}{permission} ? $node->{attributes}{permission} : 'edit';
	    $obj->{description} = $node->{attributes}{description} || '';
        if ($self->cgi->param('verbosity') && ($self->cgi->param('verbosity') eq 'full')) {
            $obj->{notebook} = $self->json->decode( $self->get_shock_file($obj->{id}, $self->shock_auth()) );
        }
        push @$objects, $obj;
    }
    return $objects;
}

# copy given nb node / update attributes and metadata
sub clone_notebook {
    my ($self, $node, $uuid, $name, $delete) = @_;
    
    my $file = $self->json->decode( $self->get_shock_file($node->{id}, $self->shock_auth()) );
    my $attr = { name => $name || $node->{attributes}{name}.'_copy',
                 nbid => $uuid,
                 type => $node->{attributes}{type} || 'generic',
                 created => strftime("%Y-%m-%dT%H:%M:%S", gmtime),
                 permission => 'edit',
                 description => $node->{attributes}{description} || ''
               };
    if ($delete) {
        $attr->{deleted} = 1;
    }
    $file->{'metadata'} = $attr;
    my $new_node = $self->set_shock_node($node->{id}.'.ipynb', $file, $attr, $self->shock_auth(1));
    $self->shock_post_acl($new_node->{id});
    return $new_node;
}

# delete notebook - we make a newer copy that we flag as deleted
sub delete_notebook {
    my ($self, $uuid) = @_;
    
    my $attr   = {nbid => $uuid};
    my @nb_set = sort {$b->{attributes}{created} cmp $a->{attributes}{created}} @{$self->get_shock_query('ipynb', $attr, $self->shock_auth())};
    my $latest = $nb_set[0];
    if ($latest->{attributes}{permission} eq 'view') {
        $self->return_data( {"ERROR" => "insufficient permissions to delete this data"}, 401 );
    }
    my $new  = $self->clone_notebook($latest, $latest->{attributes}{uuid}, $latest->{attributes}{name}, 1);
    my $data = $self->prepare_data( [$new] );
    $self->return_data($data->[0]);
}

# upload notebook file to shock / create metadata
sub upload_notebook {
    my ($self) = @_;
    
    # get notebook file
    my $tmp_dir = "$Conf::temp";
    my $fname   = $self->cgi->param('upload');
    
    # error check
    unless ($fname) {
        $self->return_data({"ERROR" => "Invalid parameters, requires filename and data"}, 400);
    }
    if ($fname =~ /\.\./) {
        $self->return_data({"ERROR" => "Invalid parameters, trying to change directory with filename, aborting"}, 400);
    }
    if ($fname !~ /^[\w\d_\.\-\:\, ]+$/) {
        $self->return_data({"ERROR" => "Invalid parameters, filename allows only word, underscore, dash, colon, comma, dot (.), space, and number characters"}, 400);
    }

    my $fhdl = $self->cgi->upload('upload');
    unless ($fhdl) {
        $self->return_data({"ERROR" => "Storing object failed - could not obtain filehandle"}, 507);
    }
    my $nb_string = "";
    my $io_handle = $fhdl->handle;
    my ($bytesread, $buffer);
    while ($bytesread = $io_handle->read($buffer,4096)) {
	    $nb_string .= $buffer;
	}

    # get notebook object and attribute object
    my $nb_obj  = $self->json->decode($nb_string);
    my $nb_attr = { name => $nb_obj->{metadata}{name} || 'Untitled',
                    nbid => $nb_obj->{metadata}{nbid} || $self->uuidv4(),
                    type => $nb_obj->{metadata}{type} || 'generic',
                    created => strftime("%Y-%m-%dT%H:%M:%S", gmtime),
                    permission => $nb_obj->{metadata}{permission} || 'edit',
                    description => $nb_obj->{metadata}{description} || ''
                  };
    $nb_obj->{'metadata'} = $nb_attr;
    
    # add to shock
    my $name = $nb_attr->{name};
    $name =~ s/\s+/_/g;
    my $node = $self->set_shock_node($name.'.ipynb', $nb_obj, $nb_attr, $self->shock_auth(1));
    $self->shock_post_acl($node->{id});
    
    my $data = $self->prepare_data( [$node] );
    $self->return_data($data->[0]);
}

sub shock_post_acl {
    my ($self, $id) = @_;
    if ($self->{nb_token} && $self->token) {
        # private
        my $email = Auth::globus_info($self->token)->{email};
        $self->add_shock_acl($id, $self->{nb_token}, $email, 'read');
        $self->add_shock_acl($id, $self->{nb_token}, $email, 'write');
    } elsif ($self->{nb_token}) {
        # public
        my $email = Auth::globus_info($self->{nb_token})->{email};
        $self->delete_shock_acl($id, $self->{nb_token}, $email, 'read');
    } else {
        # missing config
        print STDERR "Missing notebook config options\n";
    }
}

sub shock_auth {
    my ($self, $post) = @_;
    if ($post) {
        return $self->{nb_token} ? $self->{nb_token} : undef;
    } else {
        return $self->token ? $self->token : undef;
    }
}

1;
