# Theory of Operation

The EDN is for distributing random number streams to hardware blocks, via peripheral ports on on the EDN.
Each block connected to a peripheral port is referred to as an endpoint.

To enable the EDN block, set the `EDN_ENABLE` field in the [`CTRL`](../data/edn.hjson#ctrl) register..

## Interaction with CSRNG Application Interface Ports

The CSRNG application interface implements the "function envelopes" recommended by [NIST SP 800-90A](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf) for random number generation, and these function envelopes establish certain requirements for the order of operations.
For instance, the application interface port must receive an explicit `instantiate` command before receiving any `generate` commands.
The sequences of commands generated by a particular EDN are either controlled by the EDN state machine or by commands forwarded from firmware through the [`SW_CMD_REQ`](../data/edn.hjson#sw_cmd_req) register.

Whenever commands are directly forwarded from firmware to the CSRNG through the [`SW_CMD_REQ`](../data/edn.hjson#sw_cmd_req) register, firmware must poll and clear the `CMD_ACK` bit of the [`SW_CMD_STS`](../data/edn.hjson#sw_cmd_sts) register before sending any further commands.

Note that CSRNG commands are to be written into the [`SW_CMD_REQ`](../data/edn.hjson#sw_cmd_req), [`RESEED_CMD`](../data/edn.hjson#reseed_cmd), and [`GENERATE_CMD`](../data/edn.hjson#generate_cmd) registers.
CSRNG command format details can be found in [CSRNG](../../csrng/README.md).

There are two broad modes for state machine control: auto request mode and boot-time request mode.

### Boot-time Request Mode

Random values are needed by peripherals almost immediately after reset, so to simplify interactions with the boot ROM, boot-time request mode is the default mode.

In boot-time request mode, the command sequence is fully hardware-controlled and no command customization is possible.
In this mode, the EDN automatically issues a special reduced-latency `instantiate` command followed by the default `generate` commands.
This means, for instance, that no personalization strings or additional data may be passed to the CSRNG application interface port in this mode.
On exiting, the EDN issues an `uninstantiate` command to destroy the associated CSRNG instance.

Once firmware initialization is complete, it is important to exit this mode if the endpoints ever need FIPS-approved random values.
This is done by either *clearing* the `EDN_ENABLE` field or *clearing* the `BOOT_REQ_MODE` field in [`CTRL`](../data/edn.hjson#ctrl) to halt the boot-time request state machine.
Firmware must then wait for successful the shutdown of the state machine by polling the `REQ_MODE_SM_STS` field of the [`SUM_STS`](../data/edn.hjson#sum_sts) register.

It should be noted that when in boot-time request mode, no status will be updated that is used for the software port operation.
If some hang condition were to occur when in this mode, the main state machine debug register should be read to determine if a hang condition is present.
There is a limit to how much entropy can be requested in the boot-time request mode BOOT_GEN_CMD command (GLEN = 4K).
It is the responsibility of software to switch to the software mode of operation before the command has completed.
If the BOOT_GEN_CMD command ends while an endpoint is requesting, EDN will never ack and the endpoint bus will hang.

#### Note on Security Considerations when Using Boot-time Request Mode

Boot-time request mode is not intended for normal operation, as it tolerates the potential use of preliminary seeds for the attached CSRNG instance.
These preliminary seeds are described as "pre-FIPS" since they are released from the `entropy_src` before the complete start-up health-checks recommended by FIPS have been completed.
Thus pre-FIPS seeds have weaker guarantees on the amount of physical entropy included in their creation.
As detailed in the [`entropy_src` documentation](../../entropy_src/README.md), only the first CSRNG seed created after reset is pre-FIPS.
All following seeds from the `entropy_src` are passed through the full FIPS-approved health checks.
Therefore at most one EDN can receive a pre-FIPS seed after reset.
Since boot-time request mode EDN streams may be FIPS non-compliant, firmware must at some point disable boot-time request mode and reinitialize the EDN for either firmware-driven operation or auto request mode.

#### Multiple EDNs in Boot-time Request Mode

If many endpoints require boot-time entropy multiple boot-time EDNs may be required, as the EDN has a fixed maximum number of peripheral ports.
Since physical entropy generation takes time, there exists a mechanism to prioritize the EDNs, to match the boot priority of each group of attached endpoints.
To establish an order to the instantiation of each EDN, enable them one at a time.
To ensure that the most recently enabled EDN will get next priority for physical entropy, poll the `BOOT_INST_ACK` field in the [`SUM_STS`](../data/edn.hjson#sum_sts) register before enabling the following EDN.

If using boot-time request mode, the CSRNG seed material used for the first-activated EDN is the special pre-FIPS seed, which is specifically tested quickly to improve latency.
The first random values distributed from this EDN will therefore be available roughly 2ms after reset.
The `entropy_src` only creates one pre-FIPS seed, so any other EDNs must wait for their seeds to pass the full FIPS-recommended health checks.
This means that each subsequent EDN must wait an additional 5ms before it can start distributing data.
For instance, if there are three boot-time request mode EDN's in the system, the first will start distributing data 2ms after reset, the second will start distributing data 7ms after reset, and the third will start distributing data 12ms after reset.

### Auto Request Mode

Before entering auto request mode, it is the responsibility of firmware to first generate an `instantiate` command for the EDN-associated instance via the [`SW_CMD_REQ`](../data/edn.hjson#sw_cmd_req) register.
The required `generate` and `reseed` commands must also be custom generated by firmware and loaded into the respective command replay FIFOs via the [`GENERATE_CMD`](../data/edn.hjson#generate_cmd) and [`RESEED_CMD`](../data/edn.hjson#reseed_cmd) registers.
These `generate` commands will be issued as necessary to meet the bandwidth requirements of the endpoints.
The `reseed` commands will be issued once every `MAX_NUM_REQS_BETWEEN_RESEEDS` generate requests.
For details on the options for application interface commands please see the [CSRNG IP Documentation](../../csrng/README.md).
Once the CSRNG instance has been instantiated, and the `generate` and `reseed` commands have been loaded, auto request mode can be entered by programming the [`CTRL`](../data/edn.hjson#ctrl) register with `EDN_ENABLE` and `AUTO_REQ_MODE` fields are enabled.
Note that if BOOT_REQ_MODE is asserted the state machine will enter boot-time request mode, even if AUTO_REQ_MODE is asserted.

To issue any new commands other than those stored in the generate or reseed FIFOs, it is important to disable auto request mode, by deasserting the `AUTO_REQ_MODE` field in the [`CTRL`](../data/edn.hjson#ctrl) register.
Firmware must then wait until the current command is completed by polling the [`MAIN_SM_STATE`](../data/edn.hjson#main_sm_state) register.
Once the state machine returns to the `Idle` or `SWPortMode` states, new firmware-driven commands can be passed to the CSRNG via the [`SW_CMD_REQ`](../data/edn.hjson#sw_cmd_req) register.

It should be noted that when in auto request mode, no status will be updated that is used for the software port operation once the `instantiate` command has completed.
If some hang condition were to occur when in this mode, the main state machine debug register should be read to determine if a hang condition is present.

### Note on State Machine Shutdown Delays

When leaving boot-time request mode or auto request mode, the EDN state machine waits for completion of the last command, before sending a shutdown acknowledgement to firmware.
The longest possible commands are the `instantiate` or `reseed` requests, which typically take about 5ms, due to the time required to gather the necessary physical entropy.
By contrast, the largest possible `generate` command allowed by [NIST SP 800-90A](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-90Ar1.pdf) is for 2<sup>19</sup> bits (or 4096 AES codewords).
Assuming an AES encryption delay of 16 clocks, and a 100 MHz clock frequency, the longest allowable `generate` command would take only 0.7 ms to complete.

### Note on Sharing of CSRNG Instance State Variables

Once an application interface port has received an `instantiate` command, that application interface port then has access to a unique CSRNG instance, which is shared by all endpoints on the same EDN.
Therefore from a security perspective, an attack to that particular CSRNG instance is an attack on all the endpoints that share the same EDN.
Meanwhile, seeds and other state variables specific to a particular CSRNG instance are not shared between endpoints on *separate* EDN instances, or with any hardware devices with direct connections to dedicated CSRNG application interface ports.

## Interactions with Peripheral Devices

Peripheral ports distribute data to the endpoints using four signals: `req`, `ack`, `bus`, and `fips`.

Fresh (i.e. previously unseen) random values are distributed to the endpoints via the 32 bit `bus` signal, in response to a `req` signal.
Whenever new values are placed on the `bus`, the `ack` is asserted until the values are consumed by the endpoint, as indicated by simultaneous assertion of the `req` and `ack` signals in the same cycle.
Otherwise `ack` is deasserted until enough fresh bits are received from CSRNG.
The bus data will persist on the bus until a new `req` is asserted.
This persistence will allow an asynchronous endpoint to capture the correct data sometime after the `ack` de-asserts.

The `fips` signal is used to identify whether the values received on the `bus` have been prepared with complete adherence to the recommendations in NIST SP 800-90.
If the `fips` signal is deasserted, it means the associated CSRNG instance has been instantiated with a pre-FIPS seed.

## Block Diagram

![EDN Block Diagram](../doc/edn_blk_diag.svg)

## Hardware Interfaces

* [Interface Tables](../data/edn.hjson#interfaces)

## Design Details

### EDN Initialization

After power-up, the EDN block is disabled.
A single TL-UL configuration write to the  [`CTRL`](../data/edn.hjson#ctrl) register will start random-number streams processing in boot-time request mode.
CSRNG application commands will be sent immediately.
Once these commands have completed, a status bit will be set.
At this point, firmware can later come and reconfigure the EDN block for a different mode of operation.

The recommended write sequence for the entire entropy system is one configuration write to ENTROPY_SRC, then CSRNG, and finally to EDN (also see [Module enable and disable](#enable-disable)).

### Interrupts

The EDN module has two interrupts: `edn_cmd_req_done` and `edn_fatal_err`.

The `edn_cmd_req_done` interrupt should be used when a CSRNG command is issued and firmware is waiting for completion.

The `edn_fatal_err` interrupt will fire when a fatal error has been detected.
The conditions that cause this to happen are FIFO error, a state machine error state transition, or a prim_count error.

#### Waveforms

See the [CSRNG IP](../../csrng/README.md) waveform section for the CSRNG application interface commands.

##### Peripheral Hardware Interface - Req/Ack
The following waveform shows an example of how the peripheral hardware interface works.
This example shows the case where the boot-time mode in the ENTROPY_SRC block is enabled.
This example also shows the case where the next request will change the prior data by popping the data FIFO.

```wavejson
{signal: [
   {name: 'clk'           , wave: 'p...|...........|......'},
   {name: 'edn_enable'    , wave: '01..|...........|......'},
   {name: 'edn_req'       , wave: '0..1|..0..1.0...|1.0...'},
   {name: 'edn_ack'       , wave: '0...|.10...10...|.10...'},
   {name: 'edn_bus[31:0]' , wave: '0...|3....3.....|3.....', data: ['es0','es1','es2']},
   {name: 'edn_fips'      , wave: '0...|...........|......'},
 {},
]}
```