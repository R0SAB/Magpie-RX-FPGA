//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.12.01 (64-bit)
//IP Version: 1.0
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18
//Device Version: C
//Created Time: Fri Aug  7 09:48:07 2026

module gowin_osc (oscout);

output oscout;

OSC osc_inst (
    .OSCOUT(oscout)
);

defparam osc_inst.FREQ_DIV = 2;
defparam osc_inst.DEVICE = "GW2A-18C";

endmodule //gowin_osc
