
module spi_interface        // MODE 3
(
    input wire spi_cs,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_sck,

    input wire clk_70M,

    output reg [31:0] f0_word_out,
    output wire [1:0] modulation_out,
    output wire [1:0] bandwidth_out,
    output reg [7:0] volume_out,

    input wire [7:0] s_meter_value_in,
    input wire [7:0] status_byte_in
);

// ============================================================
// SPI receive register (48 bits)
// ============================================================

typedef struct packed
{
    logic [7:0]  modes;
    logic [7:0]  volume;
    logic [31:0] f0;

} spi_rx_t;

spi_rx_t spi_rx;


// ============================================================
// SPI transmit register (16 bits)
// ============================================================

typedef struct packed
{
    logic [7:0] s_meter;
    logic [7:0] status;

} spi_tx_t;

spi_tx_t spi_tx;


// ============================================================
// Output registers
// ============================================================

reg [7:0] modes;

assign modulation_out = modes[1:0];
assign bandwidth_out  = modes[3:2];


// ============================================================
// SPI reception
// ============================================================

always @(posedge spi_sck)
begin
    if (~spi_cs)
    begin
        spi_rx <= {spi_rx[46:0], spi_mosi};
    end
end


// ============================================================
// SPI CS synchronization
// ============================================================

reg [2:0] spi_cs_sync;

always @(posedge clk_70M)
begin
    spi_cs_sync <= {spi_cs_sync[1:0], spi_cs};
end

wire spi_cs_rise;

assign spi_cs_rise =
    spi_cs_sync[1] & ~spi_cs_sync[2];


// ============================================================
// Synchronized output registers
// ============================================================

always @(posedge clk_70M)
begin
    if (spi_cs_rise)
    begin
        f0_word_out <= spi_rx.f0;
        volume_out  <= spi_rx.volume;
        modes       <= spi_rx.modes;
    end
end


// ============================================================
// SPI transmission
// ============================================================

always @(negedge spi_sck or posedge spi_cs)
begin
    if (spi_cs)
    begin
        spi_tx <= {
            s_meter_value_in,
            status_byte_in
        };
    end
    else
    begin
        spi_tx <= {spi_tx[14:0], 1'b0};

        spi_miso <= spi_tx.s_meter[7];
    end
end

endmodule