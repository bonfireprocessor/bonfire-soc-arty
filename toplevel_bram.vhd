----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/16/2017 09:31:46 PM
-- Design Name: 
-- Module Name: toplevel_bram - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity toplevel_bram is
generic (
     -- generics are set by the simulator only, when instaniating from a testbench
     -- when Design is physically build than the defaults are used
     RamFileName : string := ""; -- only used when UseBRAMPrimitives is false
     mode : string := "H";       -- only used when UseBRAMPrimitives is false
     Swapbytes : boolean := true; -- SWAP Bytes in RAM word in low byte first order to use data2mem
     FakeDRAM : boolean := false; -- Use Block RAM instead of DRAM
     InstructionBurstSize : natural := 8;
     CacheSizeWords : natural := 4096 -- 16KB Instruction Cache 
   );
   port(
        CLK100MHZ  : in  std_logic;
        I_RESET   :  in  std_logic;

        -- GPIOs:
        -- 4x LEDs
        leds : out   std_logic_vector(3 downto 0);


        -- UART0 signals:
        uart0_txd : out std_logic;
        uart0_rxd : in  std_logic :='1';
        
        -- SPI flash chip
        flash_spi_cs        : out   std_logic;
        flash_spi_clk       : out   std_logic;
        flash_spi_mosi      : out   std_logic;
        flash_spi_miso      : in    std_logic

      
   
    
    );

end toplevel_bram;

architecture rtl of toplevel_bram is

constant ram_adr_width : natural := 13;
constant ram_size : natural := 8192;
 
 
constant reset_adr : std_logic_vector(31 downto 0) :=X"0C000000";

attribute mark_debug : string;

signal
       clk,        -- logical CPU clock
       locked      -- Clockgen locked 
          : std_logic;  
       

signal reset,res1,res2,res_sync_i  : std_logic;

-- Instruction Bus
--signal  ib_data : std_logic_vector(31 downto 0);
--signal  ib_busy,ib_rden : std_logic;
--signal  ib_adr : std_logic_vector(29 downto 0);

-- Instruction Bus Master
signal ibus_cyc_o:  std_logic;
signal ibus_stb_o:  std_logic;
signal ibus_cti_o:  std_logic_vector(2 downto 0);
signal ibus_bte_o:  std_logic_vector(1 downto 0);
signal ibus_ack_i:  std_logic;
signal ibus_adr_o:  std_logic_vector(29 downto 0);
signal ibus_dat_i:  std_logic_vector(31 downto 0);



-- Data Bus Master
signal  dbus_cyc_o :  std_logic;
signal  dbus_stb_o :  std_logic;
signal  dbus_we_o :  std_logic;
signal  dbus_sel_o :  std_logic_vector(3 downto 0);
signal  dbus_adr_o :  std_logic_vector(31 downto 2);
signal  dbus_dat_o :  std_logic_vector(31 downto 0);
signal  dbus_ack_i :  std_logic;
signal  dbus_dat_i :  std_logic_vector(31 downto 0);



-- Slaves
constant slave_adr_high : natural := 25;
-- Memory bus
signal mem_cyc,mem_stb,mem_we,mem_ack : std_logic;
signal mem_sel :  std_logic_vector(3 downto 0);
signal mem_dat_rd,mem_dat_wr : std_logic_vector(31 downto 0);
signal mem_adr : std_logic_vector(slave_adr_high downto 2);
signal mem_cti : std_logic_vector(2 downto 0);


-- Memory 2 bus
signal dbmem_cyc,dbmem_stb,dbmem_we,dbmem_ack : std_logic;
signal dbmem_sel :  std_logic_vector(3 downto 0);
signal dbmem_dat_rd,dbmem_dat_wr : std_logic_vector(31 downto 0);
signal dbmem_adr : std_logic_vector(slave_adr_high downto 2);
signal dbmem_cti : std_logic_vector(2 downto 0);

-- gpio bus
signal gpio_cyc,gpio_stb,gpio_we,gpio_ack : std_logic;
signal gpio_sel :  std_logic_vector(3 downto 0);
signal gpio_dat_rd,gpio_dat_wr : std_logic_vector(31 downto 0);
signal gpio_adr : std_logic_vector(slave_adr_high downto 2);


-- lpc bus
signal lpc_cyc,lpc_stb,lpc_stb0, lpc_we,lpc_ack : std_logic;
signal lpc_sel :  std_logic_vector(3 downto 0);
signal lpc_dat_rd,lpc_dat_wr : std_logic_vector(31 downto 0);
signal lpc_adr : std_logic_vector(slave_adr_high downto 2);

signal lpcio_adr : std_logic_vector(slave_adr_high downto 0);
signal lpc_dat_rd8, lpc_dat_wr8 : std_logic_vector(7 downto 0);

-- lpc slaves
-- uart bus
signal uart_cyc,uart_stb,uart_we,uart_ack : std_logic;
signal uart_sel :  std_logic_vector(3 downto 0);
signal uart_dat_rd,uart_dat_wr : std_logic_vector(7 downto 0);
signal uart_adr : std_logic_vector(7 downto 0);

-- SPI Flash
signal flash_cyc,flash_stb,flash_we,flash_ack : std_logic;
signal flash_sel :  std_logic_vector(3 downto 0);
signal flash_dat_rd,flash_dat_wr : std_logic_vector(7 downto 0);
signal flash_adr : std_logic_vector(7 downto 0);

signal irq_i : std_logic_vector(7 downto 0);

-- Interface to  dual port Block RAM
-- Port A R/W, Byte Level Access, for Data
     
signal      bram_dba_i :  std_logic_vector(31 downto 0);
signal      bram_dba_o :  std_logic_vector(31 downto 0);
signal      bram_adra_o : std_logic_vector(ram_adr_width-1 downto 0);
signal      bram_ena_o :  std_logic;
signal      bram_wrena_o :std_logic_vector (3 downto 0);  
      
-- Port B Read Only, Word level access, for Code 
signal      bram_dbb_i :  std_logic_vector(31 downto 0);
signal      bram_adrb_o : std_logic_vector(ram_adr_width-1 downto 0);
signal      bram_enb_o :  std_logic;

--attribute mark_debug of bram_dbb_i : signal is "true";
--attribute mark_debug of bram_adrb_o : signal is "true";
--attribute mark_debug of bram_enb_o : signal is "true";

component clk_wiz_0
port
 (-- Clock in ports
  -- Clock out ports
  sysclk96Mhz          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  locked            : out    std_logic;
  clk_in1           : in     std_logic
 );
end component;


begin

   irq_i <= (others=>'0'); -- currently no interrupts
   
    cpu_top: entity work.bonfire_cpu_top
       generic map (
         MUL_ARCH => "spartandsp",
         REG_RAM_STYLE => "distributed",
         START_ADDR => reset_adr(31 downto 2),
         CACHE_LINE_SIZE_WORDS =>InstructionBurstSize,
         CACHE_SIZE_WORDS=>CacheSizeWords,
         BRAM_PORT_ADR_SIZE=>ram_adr_width,
         ENABLE_TIMER=>true
       )
  
       PORT MAP(
          clk_i => clk,
          rst_i => reset,
  
          bram_dba_i => bram_dba_i,
            bram_dba_o => bram_dba_o,
            bram_adra_o => bram_adra_o,
            bram_ena_o =>  bram_ena_o,
            bram_wrena_o => bram_wrena_o,
            bram_dbb_i =>  bram_dbb_i,
            bram_adrb_o => bram_adrb_o,
            bram_enb_o =>  bram_enb_o,
            
            wb_ibus_cyc_o => ibus_cyc_o ,
            wb_ibus_stb_o => ibus_stb_o,
            wb_ibus_cti_o => ibus_cti_o,
            wb_ibus_bte_o => ibus_bte_o,
            wb_ibus_ack_i => ibus_ack_i,
            wb_ibus_adr_o => ibus_adr_o,
            wb_ibus_dat_i => ibus_dat_i,
           
            wb_dbus_cyc_o => dbus_cyc_o,
            wb_dbus_stb_o => dbus_stb_o,
            wb_dbus_we_o =>  dbus_we_o,
            wb_dbus_sel_o => dbus_sel_o,
            wb_dbus_ack_i => dbus_ack_i,
            wb_dbus_adr_o => dbus_adr_o,
            wb_dbus_dat_o => dbus_dat_o,
            wb_dbus_dat_i => dbus_dat_i,
            
            irq_i => irq_i
      );


ram: entity work.MainMemory 
        generic map (
           ADDR_WIDTH =>ram_adr_width,
           SIZE => ram_size,
           RamFileName => RamFileName,
           mode => mode,
           Swapbytes => Swapbytes,
           EnableSecondPort => true            
        )
           
      PORT MAP(
         DBOut =>   bram_dba_i,
         DBIn =>    bram_dba_o,
         AdrBus =>  bram_adra_o,
         ENA =>     bram_ena_o,
         WREN =>    bram_wrena_o,
         CLK =>     clk,
         CLKB =>    clk,
         ENB =>     bram_enb_o,
         AdrBusB => bram_adrb_o,
         DBOutB =>  bram_dbb_i
      );
      
-- DRAM "simulation"
 DRAM:  entity work.wbs_memory_interface
   GENERIC MAP (
       ram_adr_width => ram_adr_width,
       ram_size => ram_size,
       RamFileName => RamFileName,
       mode => mode,
       wbs_adr_high => slave_adr_high,
       Swapbytes => Swapbytes
   )

   PORT MAP(
       clk_i =>clk ,
       rst_i => reset,
       wbs_cyc_i =>  mem_cyc,
       wbs_stb_i =>  mem_stb,
       wbs_we_i =>    mem_we,
       wbs_sel_i =>  mem_sel,
       wbs_ack_o =>  mem_ack,
       wbs_adr_i =>  mem_adr,
       wbs_dat_i =>  mem_dat_wr,
       wbs_dat_o =>  mem_dat_rd,
       wbs_cti_i => mem_cti
              
   );
      
Inst_gpio: entity work.gpio 
        
        generic map (  wbs_adr_high => slave_adr_high)
        PORT MAP(
           leds => leds ,
           clk_i =>clk ,
           rst_i => reset,
           wbs_cyc_i => gpio_cyc ,
           wbs_stb_i => gpio_stb,
           wbs_we_i => gpio_we,
           wbs_sel_i => gpio_sel,
           wbs_ack_o => gpio_ack,
           wbs_adr_i => gpio_adr,
           wbs_dat_i => gpio_dat_wr,
           wbs_dat_o => gpio_dat_rd
       );
       
       
   -- "Low Pin Count bus"
   --  Byte addressable 8 Bit Wishbone Bus for slow devices like UARTs
   --  TODO: Byte adressing is not complete, because data are not shifted to the right position on the bus...
   
       lpc_dat_wr8<= lpc_dat_wr(7 downto 0);
       lpc_dat_rd<=  X"000000"&lpc_dat_rd8;
   
   
       -- extend Adress bus with lower two bits
      process(lpc_adr,lpc_sel)
         variable lowadr : std_logic_vector( 1 downto 0);
         begin
           case lpc_sel is
              when "0001" => lowadr:="00";
              when "0010" =>lowadr:="01";
              when "0100"=>lowadr:="10";
              when "1000"=>lowadr:="11";
              when others => lowadr:="00";
           end case;
          lpcio_adr<=lpc_adr & lowadr;
       end process;
   
   
    
      inst_lpcbus:  entity work.papro_lpc PORT MAP(
           clk_i => clk,
           rst_i => reset,
           s0_cyc_i => lpc_cyc,
           s0_stb_i => lpc_stb,
           s0_we_i =>  lpc_we,
           s0_ack_o => lpc_ack,
           s0_adr_i =>  lpcio_adr,
           s0_dat_i =>  lpc_dat_wr8,
           s0_dat_o =>  lpc_dat_rd8,
           m0_cyc_o =>  uart_cyc,
           m0_stb_o => uart_stb,
           m0_we_o =>  uart_we,
           m0_ack_i => uart_ack,
           m0_adr_o => uart_adr,
           m0_dat_o => uart_dat_wr ,
           m0_dat_i => uart_dat_rd,
           
           m1_cyc_o =>  flash_cyc,
           m1_stb_o => flash_stb,
           m1_we_o =>  flash_we,
           m1_ack_i => flash_ack,
           m1_adr_o => flash_adr,
           m1_dat_o => flash_dat_wr ,
           m1_dat_i => flash_dat_rd
           
       );
   
   
      inst_uart:  entity work.wb_uart_interface
      generic map(
      
            FIFO_DEPTH => 64 )
      
      
      PORT MAP(
           clk =>clk ,
           reset => reset,
           txd => uart0_txd,
           rxd => uart0_rxd,
           irq => open,
           wb_adr_in => uart_adr,
           wb_dat_in => uart_dat_wr,
           wb_dat_out => uart_dat_rd,
           wb_we_in => uart_we,
           wb_cyc_in => uart_cyc,
           wb_stb_in => uart_stb,
           wb_ack_out => uart_ack
       );
       
       inst_flash : entity work.wb_spi_interface 
       PORT MAP(
           clk_i => clk,
           reset_i => reset,
           slave_cs_o => flash_spi_cs,
           slave_clk_o => flash_spi_clk,
           slave_mosi_o => flash_spi_mosi,
           slave_miso_i => flash_spi_miso,
           irq => open,
           wb_adr_in =>flash_adr ,
           wb_dat_in => flash_dat_wr,
           wb_dat_out => flash_dat_rd,
           wb_we_in => flash_we,
           wb_cyc_in => flash_cyc,
           wb_stb_in => flash_stb,
           wb_ack_out => flash_ack
       );
   
   
      inst_busconnect:   entity  work.cpu_dbus_connect PORT MAP(
           clk_i => clk,
           rst_i => reset,
   
           -- Data bus
           s0_cyc_i => dbus_cyc_o,
           s0_stb_i => dbus_stb_o,
           s0_we_i =>  dbus_we_o,
           s0_sel_i => dbus_sel_o,
           s0_ack_o => dbus_ack_i,
           s0_adr_i => dbus_adr_o,
           s0_dat_i => dbus_dat_o,
           s0_dat_o => dbus_dat_i,
           
          
             -- DRAM at address   0x00000000-0x03FFFFFF
           m0_cyc_o =>  dbmem_cyc,
           m0_stb_o =>  dbmem_stb,
           m0_we_o =>   dbmem_we,
           m0_sel_o =>  dbmem_sel,
           m0_ack_i =>  dbmem_ack,
           m0_adr_o =>  dbmem_adr,
           m0_dat_o =>  dbmem_dat_wr,
           m0_dat_i =>  dbmem_dat_rd,
          
           --IO Space 1: 0x04000000-0x07FFFFF (Decode 0000 01)
           m1_cyc_o =>  gpio_cyc,
           m1_stb_o =>  gpio_stb,
           m1_we_o =>   gpio_we,
           m1_sel_o =>  gpio_sel,
           m1_ack_i =>  gpio_ack,
           m1_adr_o =>  gpio_adr,
           m1_dat_o =>  gpio_dat_wr,
           m1_dat_i =>  gpio_dat_rd,
           
           
           -- IO Space 2:  0x08000000-0x0BFFFFFF (Decode 0000 10)
           m2_cyc_o =>  lpc_cyc,
           m2_stb_o =>  lpc_stb,
           m2_we_o =>   lpc_we,
           m2_sel_o =>  lpc_sel,
           m2_ack_i =>  lpc_ack,
           m2_adr_o =>  lpc_adr,
           m2_dat_o =>  lpc_dat_wr,
           m2_dat_i =>  lpc_dat_rd 
       );
   
   -- Combine Dbus and ibus mem masters to one for interface to DRAM
   Inst_dram_arbiter:  entity work.dram_arbiter PORT MAP(
           clk_i => clk,
           rst_i => reset,
           -- DBUS has higher prio
           s0_cyc_i => dbmem_cyc,
           s0_stb_i => dbmem_stb,
           s0_we_i =>  dbmem_we,
           s0_sel_i => dbmem_sel,
           s0_cti_i => "000",
           s0_bte_i => "00",
           s0_ack_o => dbmem_ack,
           s0_adr_i => dbmem_adr,
           s0_dat_i => dbmem_dat_wr,
           s0_dat_o => dbmem_dat_rd,
           -- IBUS
           s1_cyc_i => ibus_cyc_o ,
           s1_stb_i => ibus_stb_o,
           s1_we_i =>  '0',
           s1_sel_i => "1111",
           s1_cti_i => ibus_cti_o,
           s1_bte_i => ibus_bte_o,
           s1_ack_o => ibus_ack_i,
           s1_adr_i => ibus_adr_o(ibus_adr_o'low+23 downto ibus_adr_o'low),
           s1_dat_i => (others=>'0'),
           s1_dat_o => ibus_dat_i,
           -- Interace to memory controller
           m0_cyc_o => mem_cyc,
           m0_stb_o => mem_stb,
           m0_we_o =>  mem_we,
           m0_sel_o => mem_sel,
           m0_cti_o => mem_cti,
           m0_bte_o => open,
           m0_ack_i => mem_ack,
           m0_adr_o => mem_adr,
           m0_dat_o => mem_dat_wr,
           m0_dat_i => mem_dat_rd
       );
      
     
       -- Clock and reset logic
       
       sysclk : clk_wiz_0
          port map ( 
         -- Clock out ports  
          sysclk96Mhz => clk,
         -- Status and control signals                
          reset => '0',
          locked => locked,
          -- Clock in ports
          clk_in1 => CLK100MHZ
        );
       
       reset <= res_sync_i or not locked;
       
       process(clk) begin
          if rising_edge(clk) then
            res1 <= I_RESET;
            res2 <= res1;
            res_sync_i <= res2;
          end if;
       end process;
     

end rtl;
