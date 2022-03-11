`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Amica Systems
// Engineer: Han Chenghou
// 
// Create Date: 2022/03/08 17:24:17
// Design Name: SPI_Flash_Controller
// Module Name: SPI_Flash_Programmer
// Project Name: SPI_Flash_Controller
// Target Devices: xc7a200tfbg676-2
// Tool Versions: Vivado 2018.3
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SPI_Flash_Programmer(
    input   logic         clk                       ,
    input   logic         rst_n                     ,

    output  logic         spi_serdes_rst            ,
    output  logic         spi_data_transfer_en      ,
    input   logic         spi_data_transfer_done    ,

    output  logic [ 7:0]  spi_transfer_data         ,
    input   logic [ 7:0]  spi_receive_data          ,


);
    logic   [39:0]          spi_cmd_addr_reg        ;
    logic   [23:0]          flash_id_reg            ;
    logic   [ 7:0]          command_reg             ;
    logic   [ 3:0]          command_type            ;

    logic   [11:0]          spi_fsm_cs              ;
    logic   [11:0]          spi_fsm_ns              ;
    logic   [14:0]          programmer_fsm_cs       ;
    logic   [14:0]          programmer_fsm_ns       ;
    logic   [15:0]          prog_start_counter      ;

    logic                   issue_command_en           ;

//Flash controller FSM state parameters
localparam  SPI_IDLE        =   12'b000000000001,
            SEND_CMD        =   12'b000000000010,
            SEND_ADDR_1     =   12'b000000000100,
            SEND_ADDR_2     =   12'b000000001000,
            SEND_ADDR_3     =   12'b000000010000,
            SEND_ADDR_4     =   12'b000000100000,
            REC_DATA_1      =   12'b000001000000,
            REC_DATA_2      =   12'b000010000000,
            REC_DATA_3      =   12'b000100000000,
            REC_DATA        =   12'b001000000000,
            SEND_DATA       =   12'b001000000000,


//Flash programmer FSM state parameters
localparam  PROG_IDLE       =   15'b000000000000001;
            READ_FLASH_ID   =   15'b000000000000010;
            SET_WEL_0       =   15'b000000000000100;
            ACCESS_WEL_0    =   15'b000000000001000;
            ERASE_SECTOR    =   15'b000000000010000;
            ACCESS_BUSY_0   =   15'b000000000100000;
            RESET_WEL_0     =   15'b000000001000000;
            ACCESS_WEL_1    =   15'b000000010000000;
            SET_WEL_1       =   15'b000000100000000;
            RESET_WEL_1     =   15'b000001000000000;
            PP              =   15'b000010000000000;
            ACCESS_BUSY_1   =   15'b000100000000000;
            RESET_WEL_2     =   15'b001000000000000;
            ACCESS_WEL_2    =   15'b010000000000000;
            READ_DATA       =   15'b100000000000000;

// //Command issue FSM state parameters
// localparam  CMD_IDLE        

localparam  SECTOR_ADDR     =   24'hFE0000;
















//Flash command code parameters
localparam  READ            =   8'h03,
            FAST_READ       =   8'h0B,
            2READ           =   8'hBB,
            DREAD           =   8'h3B,
            4READ           =   8'hEB,//SPI QPI
            QREAD           =   8'h6B,
            PP              =   8'h02,//SPI QPI
            4PP             =   8'h38,
            SE              =   8'h20,//SPI QPI
            BE_32K          =   8'h52,//SPI QPI
            BE              =   8'hD8,//SPI QPI
            CE              =   8'h60,//SPI QPI

            WREN            =   8'h06,//SPI QPI
            WRDI            =   8'h04,//SPI QPI
            WPSEL           =   8'h68,//SPI QPI
            EQIO            =   8'h35,
//          RSTQIO          =   8'hF5,//    QPI
            PGM_ERS_SUSPEND =   8'h75,//SPI QPI h75 or hB0
            PGM_ERS_RESUME  =   8'h7A,//SPI QPI h7A or h30
            DP              =   8'hB9,//SPI QPI
            RDP             =   8'hAB,//SPI QPI
            NOP             =   8'h00,//SPI QPI
            RSTEN           =   8'h66,//SPI QPI It is not recommended to adopt any other code/address not in the command definition table, which will potentially enter the hidden mode.
            RST             =   8'h99,//SPI QPI The RSTEN command must be executed before executing the RST command. If any other command is issued in-between RSTEN and RST, the RST command will be ignored.
            GBLK            =   8'h7E,//SPI QPI
            GBULK           =   8'h98,//SPI QPI
            FMEN            =   8'h41,//SPI QPI

            RDID            =   8'h9F,
            RES             =   8'hAB,//SPI QPI
            REMS            =   8'h90,
//          QPIID           =   8'hAF,//    QPI
            RDSFDP          =   8'h5A,
            RDSR            =   8'h05,//SPI QPI
            RDCR            =   8'h15,//SPI QPI
            WRSR_WRCR       =   8'h01,//SPI QPI
            RDSCUR          =   8'h2B,//SPI QPI
            WRSCUR          =   8'h2F,//SPI QPI
            SBL             =   8'hC0,//SPI QPI
            ENSO            =   8'hB1,//SPI QPI
            EXSO            =   8'hC1,//SPI QPI
            WRLR            =   8'h2C,
            RDLR            =   8'h2D,
            WRSPB           =   8'hE3,
            ESSPB           =   8'hE4,
            RDSPB           =   8'hE2,
            WRDPB           =   8'hE1,
            RDDPB           =   8'hE0;

//Flash command type parameters
localparam  A0_D0           =   12'b000000000001,
            A0_RD1          =   12'b000000000010,
            A0_RD2          =   12'b000000000100,
            A0_RD3          =   12'b000000001000,
            A3_D0           =   12'b000000010000,
            A4_D0           =   12'b000000100000,
            A3_RDn          =   12'b000001000000,
            A4_RDn          =   12'b000010000000,
            A3_SD256        =   12'b000100000000;



always_comb begin
    case(spi_cmd_addr_reg[39:32])
        CE              ,WREN            ,WRDI            ,WPSEL           ,EQIO            ,RSTQIO          ,PGM_ERS_SUSPEND ,PGM_ERS_RESUME  ,
        DP              ,RDP             ,NOP             ,RSTEN           ,RST             ,GBLK            ,GBULK           ,FMEN            ,
        RDSCUR          ,WRSCUR          ,ENSO            ,EXSO            ,ESSPB           :
            command_type = A0_D0;
        RDSR            ,RDCR            ,SBL             ,WRLR            ,RDLR            :
            command_type = A0_RD1;
        WRSR_WRCR       :
            command_type = A0_RD2;
        RDID            :
            command_type = A0_RD3;
        SE              :
            command_type = A3_D0;
        READ            :
            command_type = A3_RDn;
        FAST_READ       :
            command_type = A4_RDn;
        
            command_type = A3_SD256;
            //command_type = A4_D0;
        default:    command_type = A0_D0;
    endcase
end


always_ff @(posedge clk) begin
    if(~rst_n)
        issue_command_en <= 1'b0;
    else if()
        issue_command_en <= 1'b1;
end

always_ff @(posedge clk) begin
    if(~rst_n)
        spi_serdes_rst <= 1'b1;
    else if(spi_fsm_cs != SPI_IDLE)
        spi_serdes_rst <= 1'b0;
    else
        spi_serdes_rst <= 1'b1;
end

always_ff @(posedge clk) begin
    if(~rst_n)
        spi_data_transfer_en <= 1'b0;
    else if( spi_fsm_cs == SEND_CMD || spi_fsm_cs == SEND_ADDR_1 || spi_fsm_cs == SEND_ADDR_2 || spi_fsm_cs == SEND_ADDR_3 || spi_fsm_cs == SEND_DATA )
        spi_data_transfer_en <= 1'b1;
    else
        spi_data_transfer_en <= 1'b0;
end

always_comb begin
    case(spi_fsm_cs)
        SPI_IDLE    :   spi_transfer_data = 8'd0;
        SEND_CMD    :   spi_transfer_data = spi_cmd_addr_reg[39:32];
        SEND_ADDR_1 :   spi_transfer_data = spi_cmd_addr_reg[31:24];
        SEND_ADDR_2 :   spi_transfer_data = spi_cmd_addr_reg[23:16];
        SEND_ADDR_3 :   spi_transfer_data = spi_cmd_addr_reg[15: 8];
        SEND_ADDR_4 :   spi_transfer_data = spi_cmd_addr_reg[ 7: 0];
        default     :   spi_transfer_data = 8'd0;
    endcase
end

always_ff @(posedge clk) begin
    if(~rst_n)
        spi_cmd_addr_reg <= 40'b0;
    else
        case(programmer_fsm_cs)
            PROG_IDLE       :        spi_cmd_addr_reg <= 40'b0                  ;
            READ_FLASH_ID   :        spi_cmd_addr_reg <= { RDID , NOP , NOP , NOP , NOP };
            SET_WEL_0       :        spi_cmd_addr_reg <= { WREN , NOP , NOP , NOP , NOP };
            ACCESS_WEL_0    :        spi_cmd_addr_reg <= { RDSR , NOP , NOP , NOP , NOP };
            ERASE_SECTOR    :        spi_cmd_addr_reg <= { SE , SECTOR_ADDR , NOP };
            ACCESS_BUSY_0   :        spi_cmd_addr_reg <= { RDSR , NOP , NOP , NOP , NOP };
            RESET_WEL_0     :        spi_cmd_addr_reg <= { WRDI , NOP , NOP , NOP , NOP };
            ACCESS_WEL_1    :        spi_cmd_addr_reg <= { RDSR , NOP , NOP , NOP , NOP };
            SET_WEL_1       :        spi_cmd_addr_reg <= { WREN , NOP , NOP , NOP , NOP };
            RESET_WEL_1     :        spi_cmd_addr_reg <= { WRDI , NOP , NOP , NOP , NOP };
            PP              :        spi_cmd_addr_reg <= { PP , SECTOR_ADDR , NOP };
            ACCESS_BUSY_1   :        spi_cmd_addr_reg <= { RDSR , NOP , NOP , NOP , NOP };
            RESET_WEL_2     :        spi_cmd_addr_reg <= { WRDI , NOP , NOP , NOP , NOP };
            ACCESS_WEL_2    :        spi_cmd_addr_reg <= { RDSR , NOP , NOP , NOP , NOP };
            READ_DATA       :        spi_cmd_addr_reg <= { READ , SECTOR_ADDR , NOP };
            default         :        spi_cmd_addr_reg <= 40'b0                  ;
        endcase
end












//Flash controller FSM
always_ff @(posedge clk) begin
    if(~rst_n)
        spi_fsm_cs <= SPI_IDLE;
    else
        spi_fsm_cs <= spi_fsm_ns;
end

always_comb begin
    if(~rst_n)
        spi_fsm_ns = SPI_IDLE;
    else
        case(spi_fsm_cs)
            SPI_IDLE        :   if(issue_command_en)
                                    spi_fsm_ns    =   SEND_CMD    ;
                                else
                                    spi_fsm_ns    =   SPI_IDLE        ;
            SEND_CMD        :   case(command_type)
                                    A0_D0       :
                                                 spi_fsm_ns     =   SPI_IDLE        ;
                                    A3_D0       ,A4_D0      ,A3_RDn      ,A4_RDn      ,A3_SD256 :
                                                 spi_fsm_ns     =   SEND_ADDR_1     ;
                                    A0_RD1      ,A0_RD2      ,A0_RD3      :
                                                 spi_fsm_ns     =   REC_DATA_1      ;
                                    default     :spi_fsm_ns     =   SEND_CMD        ;
                                endcase
            SEND_ADDR_1     :   if(spi_data_transfer_done)
                                    spi_fsm_ns     =   SEND_ADDR_2     ;
                                else
                                    spi_fsm_ns     =   SEND_ADDR_1     ;
            SEND_ADDR_2     :   if(spi_data_transfer_done)
                                    spi_fsm_ns     =   SEND_ADDR_3     ;
                                else
                                    spi_fsm_ns     =   SEND_ADDR_2     ;
            SEND_ADDR_3     :   if(spi_data_transfer_done)
                                    case(command_type)
                                        A3_D0       :spi_fsm_ns     =   SPI_IDLE    ;
                                        A4_D0       ,A4_RDn     :
                                                    :spi_fsm_ns     =   SEND_ADDR_4 ;
                                        A3_RDn      :spi_fsm_ns     =   REC_DATA    ;
                                        A3_SD256    :spi_fsm_ns     =   SEND_DATA   ;
                                        default     :spi_fsm_ns     =   SEND_ADDR_3 ;
                                    endcase
                                else
                                    spi_fsm_ns     =   SEND_ADDR_3  ;
            SEND_ADDR_4     :   if(spi_data_transfer_done && command_type == A4_D0)
                                    spi_fsm_ns     =   SPI_IDLE     ;
                                else if(spi_data_transfer_done && command_type == A4_RDn)
                                    spi_fsm_ns     =   REC_DATA     ;
                                else
                                    spi_fsm_ns     =   SEND_ADDR_4  ;
            REC_DATA_1      :   if(spi_data_transfer_done)
                                    case(command_type)
                                        A0_RD2      ,A0_RD3      :
                                            spi_fsm_ns    =   REC_DATA_2      ;
                                        A0_RD1      :
                                            spi_fsm_ns    =   SPI_IDLE        ;
                                        default     :
                                            spi_fsm_ns    =   REC_DATA_1      ;
                                    endcase
                                else
                                    spi_fsm_ns     =   REC_DATA_1   ;
            REC_DATA_2      :   if(spi_data_transfer_done && command_type == A0_RD2)
                                    spi_fsm_ns     =   SPI_IDLE     ;
                                else if(spi_data_transfer_done && command_type == A0_RD3)
                                    spi_fsm_ns     =   REC_DATA_3   ;
                                else
                                    spi_fsm_ns     =   REC_DATA_2   ;
            REC_DATA_3      :   if(spi_data_transfer_done)
                                    spi_fsm_ns     =   SPI_IDLE     ;
                                else
                                    spi_fsm_ns     =   REC_DATA_3   ;
            REC_DATA        :   
                                
            SEND_DATA       :   
                                
            default         :   spi_fsm_ns    =   SPI_IDLE;

        endcase
end













//Flash programmer FSM

always_ff @(posedge clk) begin
    if(~rst_n)
        programmer_fsm_cs <= PROG_IDLE;
    else
        programmer_fsm_cs <= programmer_fsm_ns;
end

always_comb begin
    if(~rst_n)
        programmer_fsm_ns = PROG_IDLE;
    else
        case(programmer_fsm_cs)
            PROG_IDLE       :       if(prog_start_counter[15])
                                        programmer_fsm_ns = READ_FLASH_ID   ;
                                    else
                                        programmer_fsm_ns = PROG_IDLE       ;
            READ_FLASH_ID   :       if()
                                        programmer_fsm_ns = SET_WEL_0       ;
                                    else
                                        programmer_fsm_ns = READ_FLASH_ID   ;
            SET_WEL_0       :       if()
                                        programmer_fsm_ns = ACCESS_WEL_0    ;
                                    else
                                        programmer_fsm_ns = SET_WEL_0       ;
            ACCESS_WEL_0    :       if()
                                        programmer_fsm_ns = ERASE_SECTOR    ;
                                    else
                                        programmer_fsm_ns = ACCESS_WEL_0    ;
            ERASE_SECTOR    :       if()
                                        programmer_fsm_ns = ACCESS_BUSY_0   ;
                                    else
                                        programmer_fsm_ns = ERASE_SECTOR    ;
            ACCESS_BUSY_0   :       if()
                                        programmer_fsm_ns = RESET_WEL_0     ;
                                    else
                                        programmer_fsm_ns = ACCESS_BUSY_0   ;
            RESET_WEL_0     :       if()
                                        programmer_fsm_ns = ACCESS_WEL_1    ;
                                    else
                                        programmer_fsm_ns = RESET_WEL_0     ;
            ACCESS_WEL_1    :       if()
                                        programmer_fsm_ns = SET_WEL_1       ;
                                    else
                                        programmer_fsm_ns = ACCESS_WEL_1    ;
            SET_WEL_1       :       if()
                                        programmer_fsm_ns = RESET_WEL_1     ;
                                    else
                                        programmer_fsm_ns = SET_WEL_1       ;
            RESET_WEL_1     :       if()
                                        programmer_fsm_ns = PP              ;
                                    else
                                        programmer_fsm_ns = RESET_WEL_1     ;
            PP              :       if()
                                        programmer_fsm_ns = ACCESS_BUSY_1   ;
                                    else
                                        programmer_fsm_ns = PP              ;
            ACCESS_BUSY_1   :       if()
                                        programmer_fsm_ns = RESET_WEL_2     ;
                                    else
                                        programmer_fsm_ns = ACCESS_BUSY_1   ;
            RESET_WEL_2     :       if()
                                        programmer_fsm_ns = ACCESS_WEL_2    ;
                                    else
                                        programmer_fsm_ns = RESET_WEL_2     ;
            ACCESS_WEL_2    :       if()
                                        programmer_fsm_ns = READ_DATA       ;
                                    else
                                        programmer_fsm_ns = ACCESS_WEL_2    ;
            READ_DATA       :       
                                    programmer_fsm_ns = READ_DATA           ;
            default         :       
                                    programmer_fsm_ns = PROG_IDLE           ;
        endcase
end



always_ff @(posedge clk) begin
    if(~rst_n)
        prog_start_counter <= 16'd0;
    else if(~prog_start_counter[15])
        prog_start_counter <= prog_start_counter + 1'b1;
    else
        prog_start_counter <=prog_start_counter;
end






// //Command issue FSM
// always_ff @(posedge clk) begin
//     if(~rst_n)
//         command_fsm_cs <= PROG_IDLE;
//     else
//         programmer_fsm_cs <= programmer_fsm_ns;
// end

// always_comb begin
//     if(~rst_n)
//         programmer_fsm_ns = PROG_IDLE;
//     else
//         case(programmer_fsm_cs)












endmodule
