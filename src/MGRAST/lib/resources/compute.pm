package resources::compute;

use strict;
use warnings;
no warnings('once');

use File::Temp qw(tempfile tempdir);
use Conf;
use parent qw(resources::resource);

# Override parent constructor
sub new {
    my ($class, @args) = @_;

    # Call the constructor of the parent class
    my $self = $class->SUPER::new(@args);
    
    # Add name / attributes
    $self->{name} = "compute";
    $self->{attributes} = { "data" => [ 'object', 'return data' ] };
    return $self;
}

# resource is called without any parameters
# this method must return a description of the resource
sub info {
    my ($self) = @_;
    my $content = { 'name' => $self->name,
		            'url' => $self->cgi->url."/".$self->name,
		            'description' => "Calculate a PCoA for given input data.",
		            'type' => 'object',
		            'documentation' => $self->cgi->url.'/api.html#'.$self->name,
		            'requests' => [
		                { 'name'        => "info",
				          'request'     => $self->cgi->url."/".$self->name,
				          'description' => "Returns description of parameters and attributes.",
				          'method'      => "GET" ,
				          'type'        => "synchronous" ,  
				          'attributes'  => "self",
				          'parameters'  => { 'options'  => {},
							                 'required' => {},
							                 'body'     => {} }
						},
				        { 'name'        => "normalize",
				          'request'     => $self->cgi->url."/".$self->name."/normalize",
				          'description' => "Calculate normalized values for given input data.",
				          'method'      => "POST" ,
				          'type'        => "synchronous",
				          'attributes'  => $self->{attributes},
				          'parameters'  => { 'options'  => {},
							                 'required' => {},
							                 'body'     => {} }
						},
						{ 'name'        => "heatmap",
				          'request'     => $self->cgi->url."/".$self->name."/heatmap",
				          'description' => "Calculate a dendogram for given input data.",
				          'method'      => "POST" ,
				          'type'        => "synchronous",
				          'attributes'  => $self->{attributes},
				          'parameters'  => { 'options'  => {},
							                 'required' => {},
							                 'body'     => {} }
						},
						{ 'name'        => "pcoa",
				          'request'     => $self->cgi->url."/".$self->name."/pcoa",
				          'description' => "Calculate a PCoA for given input data.",
				          'method'      => "POST" ,
				          'type'        => "synchronous",
				          'attributes'  => $self->{attributes},
				          'parameters'  => { 'options'  => {},
							                 'required' => {},
							                 'body'     => { "auth" => [ "string", "unique string of text generated by MG-RAST for your account"
							                                 "upload" => ["file", "file to run compute on"] } }
						},
				     ]
				 };

    $self->return_data($content);
}

sub instance {
    my ($self) = @_;

    # check auth
    unless ($self->user) {
        $self->return_data( {"ERROR" => "authentication failed"}, 401 );
    }

    # get file
    my $infile;
    my $fname = $self->cgi->param('upload');
    if ($fname) {
        if ($fname =~ /\.\./) {
            $self->return_data({"ERROR" => "Invalid parameters, trying to change directory with filename, aborting"}, 400);
        }
        if ($fname !~ /^[\w\d_\.]+$/) {
            $self->return_data({"ERROR" => "Invalid parameters, filename allows only word, underscore, dot (.), and number characters"}, 400);
        }
        my $fhdl = $self->cgi->upload('upload');
        if (defined $fhdl) {
            my ($bytesread, $buffer);
            my $io_handle = $fhdl->handle;
            my ($tfh, $tfile) = tempfile($self->rest->[0]."XXXXXXX", DIR => $Conf::temp, SUFFIX => '.txt');
            while ($bytesread = $io_handle->read($buffer, 4096)) {
                print $tfh $buffer;
            }
            close $tfh;
            chmod 0666, $tfile;
            $infile = $tfile;
        } else {
            $self->return_data( {"ERROR" => "storing object failed - could not open target file"}, 507 );
        }
    else {
        $self->return_data({"ERROR" => "Invalid parameters, requires filename and data"}, 400);
    }
    
    my $data;    
    # nomalize
    if ($self->rest->[0] eq 'normalize') {
        my $ofile = $self->normalize($infile);
        $data = { data => $self->read_file($ofile) };
    }
    # heatmap
    elsif ($self->rest->[0] eq 'heatmap') {
        my ($cfile, $rfile) = $self->heatmap($infile);
        $data = { data => {'col' => $self->read_file($cfile), 'row' => $self->read_file($rfile)} };
    }
    # pcoa
    elsif ($self->rest->[0] eq 'pcoa') {
        my $ofile = $self->pcoa($infile);
        $data = { data => $self->read_file($ofile) };
    }
    else {
        $self->info();
    }
    
    $self->return_data($data);
}

sub normalize {
    my ($self, $fname) = @_;
    
    my $time = time;
    my $fout = $Conf::temp."/rdata.normalize.".$time;
    my ($rfh, $rfn) = tempfile("rnormalizeXXXXXXX", DIR => $Conf::temp, SUFFIX => '.txt');
    print $rfh "source(\"".$Conf::bin."/preprocessing.r\")\n";
    print $rfh "MGRAST_preprocessing(file_in = \"".$fname."\", file_out = \"".$fout."\", produce_fig = \"FALSE\")\n";
    close $rfh;
    
    $self->run_r($fname, $rfn);
    return $fout;
}

sub heatmap {
    my ($self, $fname) = @_;

    my $dist  = $self->cgi->param('distance') || 'bray-curtis';
    my $clust = $self->cgi->param('cluster') || 'ward';
    my $time  = time;
    my ($fcol, $frow) = ($Conf::temp."/rdata.col.$time", $Conf::temp."/rdata.row.$time");
    my ($rfh, $rfn) =  tempfile("rheatXXXXXXX", DIR => $Conf::temp, SUFFIX => '.txt');
	print $rfh "source(\"".$Conf::bin."/dendrogram.r\")\n";
	print $rfh "MGRAST_dendrograms(file_in = \"".$fname."\", file_out_column = \"".$fcol."\", file_out_row = \"".$frow."\", dist_method = \"".$dist."\", clust_method = \"".$clust."\", produce_figures = \"FALSE\")\n";
	close $rfh;

    my $time = time;
    my $fout = $Conf::temp."/rdata.pcoa.".$time;
    my ($rfh, $fn) =  tempfile("rpcaXXXXXXX", DIR => $Conf::temp, SUFFIX => '.txt');
    print $rfh "source(\"".$Conf::bin."/plot_pco.r\")\n";
    print $rfh "MGRAST_plot_pco(file_in = \"".$fname."\", file_out = \"".$fout."\", dist_method = \"bray-curtis\", headers = 0)\n";
    close $rfh;
    
    $self->run_r($fname, $rfn);
    return ($fcol, $frow);
}

sub pcoa {
    my ($self, $fname) = @_;

    my $dist = $self->cgi->param('distance') || 'bray-curtis';
    my $time = time;
    my $fout = $Conf::temp."/rdata.pcoa.".$time;
    my ($rfh, $fn) =  tempfile("rpcaXXXXXXX", DIR => $Conf::temp, SUFFIX => '.txt');
    print $rfh "source(\"".$Conf::bin."/plot_pco.r\")\n";
    print $rfh "MGRAST_plot_pco(file_in = \"".$fname."\", file_out = \"".$fout."\", dist_method = \"".$dist."\", headers = 0)\n";
    close $rfh;
    
    $self->run_r($fname, $rfn);
    return $fout;
}

sub run_r {
    my ($self, $input, $rfile) = @_;
    my $R = ($Conf::r_executable) ? $Conf::r_executable : "R";
    `$R --vanilla --slave < $rfile`;
    unlink($input, $rfile);
}

sub read_file {
    my ($self, $fname) = @_;
    my $data = "";
    eval {
        open(DFH, "<$fname");
        $data = do { local $/; <DFH> };
        close DFH;
        unlink $fname;
    };
    if ($@ || (! $data)) {
        $self->return_data({"ERROR" => "Unable to retrieve results."}, 400);
    }
    return $data;
}

1;
