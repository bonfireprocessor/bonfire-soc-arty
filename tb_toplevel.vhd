----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/17/2017 09:01:39 PM
-- Design Name: 
-- Module Name: tb_toplevel - Behavioral
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
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_toplevel is
--  Port ( );
end tb_toplevel;

architecture Behavioral of tb_toplevel is

COMPONENT toplevel_bram
     generic (
    -- generics are set by the simulator only, when instaniating from a testbench
    -- when Design is physically build than the defaults are used
    RamFileName : string;-- only used when UseBRAMPrimitives is false
     mode : string;       -- only used when UseBRAMPrimitives is false
    Swapbytes : boolean := true; -- SWAP Bytes in RAM word in low byte first order to use data2mem
    FakeDRAM : boolean := false; -- Use Block RAM instead of DRAM
    InstructionBurstSize : natural := 8
    );
   PORT(
       CLK100MHZ : IN std_logic;
       I_RESET : IN std_logic;
       uart0_rxd : IN std_logic;
       uart0_txd : OUT std_logic;
     
         
       leds : OUT std_logic_vector(3 downto 0);
    
       flash_spi_cs : OUT std_logic;
       flash_spi_clk : OUT std_logic;
       flash_spi_mosi : OUT std_logic;
       flash_spi_miso : IN std_logic 
     
     
       );
END COMPONENT;
    
     --Inputs
      signal CLK100MHZ : std_logic := '0';
      signal I_RESET : std_logic := '0';
      signal uart0_rxd : std_logic := '0';
      
      	--Outputs
       signal leds : std_logic_vector(3 downto 0);
       signal uart0_txd : std_logic;
       signal flash_spi_cs,flash_spi_clk,flash_spi_loopback : std_logic;
    
 -- Clock period definitions
       constant clock_period : time := 10ns;


begin

uut:  toplevel_bram 
   
    generic map (
        --RamFileName => "../../lxp32soc/software/wildfire/test/jump0.hex",
        --RamFileName => "../../lxp32soc/software/wildfire/test/dram_codesim.hex",
        RamFileName => "/home/thomas/development/bonfire/bonfire-soc/software/wildfire/monitor/monitor.hex",
        --RamFileName => "../../lxp32soc/software/wildfire/test/memsim.hex",
        --RamFileName => "../../lxp32soc/software/wildfire/test/sim_hello.hex",
        --RamFileName => "../../lxp32soc/riscv/software/cpptest/counter.hex",
         --RamFileName => "../../lxp32-cpu/riscv_test/branch.hex",
        --RamFileName => "../../lxp32-cpu/riscv_test/trap01.hex",
        --RamFileName => "../../lxp32-cpu/riscv_test/mult.hex",
        mode=>"H",
        FakeDRAM=>true,
        Swapbytes=>false,
        InstructionBurstSize => 8
     )     
   
   
   PORT MAP (
          CLK100MHZ => CLK100MHZ,
          I_RESET => I_RESET,
          leds => leds,
          uart0_txd => uart0_txd,
          uart0_rxd => uart0_rxd,
       
          flash_spi_cs =>flash_spi_cs ,
		  flash_spi_clk => flash_spi_clk,
		  flash_spi_mosi => flash_spi_loopback,
		  flash_spi_miso => flash_spi_loopback
          
        
        );
        
        
 -- Clock process definitions
          clock_process :process
          begin
               CLK100MHZ <= '0';
               wait for clock_period/2;
               CLK100MHZ <= '1';
               wait for clock_period/2;
          end process;
        
       
          -- Stimulus process
          stim_proc: process
          begin        
             -- hold reset state for 100 ns.
             
             wait for 3500 ns;    
             I_RESET<='1';
             wait for 2000ns;
             I_RESET<='0';
            
       
             -- insert stimulus here 
       
             wait;
          end process;        
        


end Behavioral;
