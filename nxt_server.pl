#!/usr/bin/perl -w

#################################################################################
# Configuracion

my $INPORT = 1234;
my $TOPORT = 2345;

#################################################################################

use threads;
use threads::shared;
use Thread::Semaphore;
use IO::Socket::INET;
use LEGO::NXT;
use LEGO::NXT::BlueComm;
use LEGO::NXT::Constants qw(:DEFAULT);
use Net::Bluetooth;
use Data::Dumper;
use strict;

print ">> NXT Bluetooth Server <<\n";

# Create a new socket
my $InSocket = new IO::Socket::INET->new( LocalPort => $INPORT, Proto => 'udp');
die "Failure creating in socket!\n" if ( !$InSocket );

my $OutSocket = new IO::Socket::INET->new(PeerPort=>$TOPORT, Proto=>'udp',
					PeerAddr=>'255.255.255.255', Broadcast => 1);
die "Failure creating out socket!\n" if ( !$OutSocket );

# Estado. Hash de id (p.ej.bluetooth address) -> command
# Asocia una direccion con el ultimo comando pendiente
# Se inicializa con una entrada especial para broadcast
my %state_shared : shared = ();
$state_shared{ALL} = '';

# Semaforo para acceder a los mensajes pendientes
my $semaphore = new Thread::Semaphore(0);

#Handlers de los robots
my %nxt_handlers = ();

my $bluetooth_port = 1;


#################################################################################
# Programa Principal
sub main {

	# Creamos y liberamos thread para procesar mensajes
	my $thread_monitor    = threads->new( \&monitor_messages );
	$thread_monitor->detach();

	my ( $msg_sock, $address, $command );
	my $new_command_available = 0;

	# Keep receiving messages from client
	while (1) {
		$InSocket->recv( $msg_sock, 128 );
#print "+\n";
		my ( $address, $command ) = split( /,/, $msg_sock, 2 );

		{
			lock(%state_shared);

			if ( !exists $state_shared{$address}
				|| $state_shared{$address} eq '' )
			{
				$new_command_available = 1;
			}
			$state_shared{$address} = $command;
			if ( $new_command_available == 1 ) {
				$semaphore->up();
				$new_command_available = 0;
			}

		}

	}
}
#################################################################################

#################################################################################
# Procesar mensajes (corre en un thread)
sub monitor_messages {
	my ( $robot, $command ) = ( '', '' );
	my $nxt_handler;

	# Nos bloqueamos al arrancar
	$semaphore->down();

	while (1) {

		#Buscamos un mensaje pendiente y lo reseteamos
		{
			lock(%state_shared);

			until (  ( ( $robot, $command ) = each(%state_shared) )
				  && ( $command ne '' ) )
			{
			}

			$state_shared{$robot} = '';

		}

		# vemos si es un robot solo, o broadcast
		if ( $robot ne 'ALL' ) {
			$nxt_handler = &get_handler($robot);
			defined($nxt_handler) && &send_command( $robot, $nxt_handler, $command );
		}
		else {
			#foreach $irobot ( keys %nxt_handlers ) {

			while( my ($address, $nxt_handler) = each %nxt_handlers ) {
				#print "key: $address, value: $nxt_handler.\n";
				send_command( $address, $nxt_handler, $command );
			}
		}

		# Acabamos de consumimos uno
		$semaphore->down();

	}

}
#################################################################################


#################################################################################
# Lee el voltaje desde un handler, y lo reporta en outsocket
# read_battery_level ($address, $handler)
sub read_battery_level {
	my ( $robot, $nxt ) = ( $_[0], $_[1]);
	print("Getting battery level from $robot... ");
	# $res = $nxt->get_battery_level($NXT_RET)
	my $res = $nxt->get_battery_level($NXT_RET);
	my $volts = ($$res{battery_mv})/1000;
	print "done: $volts V\n";
	$OutSocket->send("$robot info battery_level $volts\n");
}
#################################################################################

#################################################################################
# Busca el handler para un robot. Crea handlers a demanda.
# get_handler ($robot)
sub get_handler {
	my $robot = $_[0];
	my $nxt_handler;

	#verifico si tengo que conectar
	if ( exists $nxt_handlers{$robot} ) {
		$nxt_handler = $nxt_handlers{$robot};
	}
	else {
		print "New robot on $robot\n";
		my $thread_newhandler = threads->new( \&new_handler, $robot );
		$nxt_handler = $thread_newhandler->join;

		defined($nxt_handler) && ( $nxt_handlers{$robot} = $nxt_handler );
	}
	$nxt_handler;
}
#################################################################################

#################################################################################
# Crea un handler para un robot. En un thread aparte, por si revienta al fallar
# la conexion.
# new_handler ($robot)
sub new_handler {
	my $robot = $_[0];
	my $nxt_handler;

	$nxt_handler =
	  LEGO::NXT->new( new LEGO::NXT::BlueComm( $robot, $bluetooth_port ) );

	#enviamos un mensaje. Si la conexion fallo, el thread muere.
	read_battery_level($robot, $nxt_handler);

	$nxt_handler;
}
#################################################################################

#################################################################################
# Parsea comando y lo envia usando un handler
# process_command ($nxt_handler, $command)
sub send_command {
	my ( $robot, $nxt, $command ) = ( $_[0], $_[1], $_[2] );
	my @tokens      = split( /,/, $command );
	my $instruction = $tokens[0];

	#my $nxt = &get_handler($robot);
	#if (!defined($nxt)) { return; }

#print("+ $instruction\n");

	#procesar mensaje
  SWITCH: {
		if ( $instruction eq 'keep_alive' ) {

			# $nxt->keep_alive($NXT_NORET)
			$nxt->keep_alive($NXT_NORET);
			last SWITCH;
		}
		if ( $instruction eq 'set_stop_sound_playback' ) {

			# $nxt->set_stop_sound_playback($NXT_NORET)
			$nxt->set_stop_sound_playback($NXT_NORET);
			last SWITCH;
		}
		if ( $instruction eq 'play_sound_file' ) {

			# $nxt->play_sound_file($NXT_NORET,$repeat,$file)
			$nxt->play_sound_file( $NXT_NORET, $tokens[1], $tokens[2] );
			last SWITCH;
		}
		if ( $instruction eq 'play_tone' ) {

			# $nxt->play_tone($NXT_NORET,$pitch,$duration)
			$nxt->play_tone( $NXT_NORET, $tokens[1], $tokens[2] );
			last SWITCH;
		}
		if ( $instruction eq 'set_output_state' ) {
			# $nxt->set_output_state($NXT_NORET,$port,$power,$mode,$regulation,
			#                        $turnratio,$runstate,$tacholimit)
			$nxt->set_output_state(
				$NXT_NORET, $tokens[1],	$tokens[2], $tokens[3],	$tokens[4], 
				$tokens[5], $tokens[6],	$tokens[7]
			);
			last SWITCH;
		}
		if ( $instruction eq 'set_output_state_3' ) {
			# $nxt->set_output_state_3($NXT_NORET,$v1,$v2,$v3)
			# Envio de velocidades a motor A, B y C (para pgomni)

			if ( $tokens[1] eq '0'){
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_A,$tokens[1], $NXT_BRAKE ,$NXT_REGULATION_MODE_IDLE,0,
					$NXT_MOTOR_RUN_STATE_IDLE,0 
				);
			}
			else {
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_A,$tokens[1], $NXT_MOTOR_ON | $NXT_REGULATED,$NXT_REGULATION_MODE_MOTOR_SPEED,0,
					$NXT_MOTOR_RUN_STATE_RUNNING,0 
				);
			}
			if ( $tokens[2] eq '0'){
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_B,$tokens[2], $NXT_BRAKE ,$NXT_REGULATION_MODE_IDLE,0,
					$NXT_MOTOR_RUN_STATE_IDLE,0 
				);
			}
			else {
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_B,$tokens[2], $NXT_MOTOR_ON | $NXT_REGULATED,$NXT_REGULATION_MODE_MOTOR_SPEED,0,
					$NXT_MOTOR_RUN_STATE_RUNNING,0 
				);
			}
			if ( $tokens[3] eq '0'){
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_C,$tokens[3], $NXT_BRAKE ,$NXT_REGULATION_MODE_IDLE,0,
					$NXT_MOTOR_RUN_STATE_IDLE,0 
				);
			}
			else {
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_C,$tokens[3], $NXT_MOTOR_ON | $NXT_REGULATED,$NXT_REGULATION_MODE_MOTOR_SPEED,0,
					$NXT_MOTOR_RUN_STATE_RUNNING,0 
				);	
			}
			last SWITCH;
		}
		if ( $instruction eq 'set_output_state_2' ) {
			# $nxt->set_output_state_2($NXT_NORET,$v1,$v2)
			# Envio de velocidades a motor A y B (para sumo, pedido por Santiago Margni)

			if ( $tokens[1] eq '0'){
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_A,$tokens[1], $NXT_BRAKE ,$NXT_REGULATION_MODE_IDLE,0,
					$NXT_MOTOR_RUN_STATE_IDLE,0 
				);
			}
			else {
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_A,$tokens[1], $NXT_MOTOR_ON | $NXT_REGULATED,$NXT_REGULATION_MODE_MOTOR_SPEED,0,
					$NXT_MOTOR_RUN_STATE_RUNNING,0 
				);
			}
			if ( $tokens[2] eq '0'){
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_B,$tokens[2], $NXT_BRAKE ,$NXT_REGULATION_MODE_IDLE,0,
					$NXT_MOTOR_RUN_STATE_IDLE,0 
				);
			}
			else {
				$nxt->set_output_state(
					$NXT_NORET, $NXT_MOTOR_B,$tokens[2], $NXT_MOTOR_ON | $NXT_REGULATED,$NXT_REGULATION_MODE_MOTOR_SPEED,0,
					$NXT_MOTOR_RUN_STATE_RUNNING,0 
				);
			}			
			last SWITCH;
		}
		if ( $instruction eq 'start_program' ) {

			# $nxt->start_program($NXT_NORET,$filename)
			$nxt->start_program( $NXT_NORET, $tokens[1] );
			last SWITCH;
		}
		if ( $instruction eq 'stop_program' ) {

			# $nxt->stop_program($NXT_NORET)
			$nxt->stop_program($NXT_NORET);
			last SWITCH;
		}
		if ( $instruction eq 'get_battery_level' ) {

			read_battery_level($robot, $nxt);
			last SWITCH;
		}
		if ( $instruction eq 'info' ) {
			print "# $command\n";
			last SWITCH;
		}
		print "Non supported instruction: $instruction\n";
	}

}
#################################################################################

&main;

