----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Copyright 2016 International Business Machines
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions AND
-- limitations under the License.
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------

LIBRARY ieee;--, ibm, ibm_asic;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;



USE work.afu_types.ALL;

ENTITY action_interface IS
  PORT (

    clk_fw   : in  std_ulogic;   
    clk_app  : in  std_ulogic; 
    rst      : in  std_ulogic; 
    xk_d_i   : in  XK_D_T;
    kx_d_o   : out KX_D_T;        
    sk_d_i   : in  SK_D_T; 
    ks_d_o   : out KS_D_T
  
  );
END action_interface;

ARCHITECTURE action_interface OF action_interface IS
 

component action_wrapper is
    port (
    clk : in STD_LOGIC;
    m_axi_araddr        : out STD_LOGIC_VECTOR ( 63 downto 0 );
    m_axi_arburst       : out STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_arcache       : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_arlen         : out STD_LOGIC_VECTOR ( 7 downto 0 );
--    m_axi_arlock        : out STD_LOGIC_VECTOR ( 0 downto 0 );
    m_axi_arlock        : out STD_LOGIC;
    m_axi_arprot        : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_arqos         : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_arid          : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axi_awid          : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axi_aruser        : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axi_awuser        : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axi_arready       : in STD_LOGIC;
--    m_axi_arregion      : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_arsize        : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_arvalid       : out STD_LOGIC;
    m_axi_awaddr        : out STD_LOGIC_VECTOR ( 63 downto 0 );
    m_axi_awburst       : out STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_awcache       : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_awlen         : out STD_LOGIC_VECTOR ( 7 downto 0 );
    m_axi_awlock        : out STD_LOGIC;
--    m_axi_awlock        : out STD_LOGIC_VECTOR ( 0 downto 0 );
    m_axi_awprot        : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_awqos         : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_awready       : in STD_LOGIC;
    -- m_axi_awregion      : out STD_LOGIC_VECTOR ( 3 downto 0 );
    m_axi_awsize        : out STD_LOGIC_VECTOR ( 2 downto 0 );
    m_axi_awvalid       : out STD_LOGIC;
    m_axi_bready        : out STD_LOGIC;
    m_axi_bresp         : in STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_bvalid        : in STD_LOGIC;
    m_axi_rdata         : in STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axi_rlast         : in STD_LOGIC;
    m_axi_rready        : out STD_LOGIC;
    m_axi_rresp         : in STD_LOGIC_VECTOR ( 1 downto 0 );
    m_axi_rvalid        : in STD_LOGIC;
    m_axi_wdata         : out STD_LOGIC_VECTOR ( 127 downto 0 );
    m_axi_wlast         : out STD_LOGIC;
    m_axi_wready        : in STD_LOGIC;
    m_axi_wuser         : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axi_wstrb         : out STD_LOGIC_VECTOR ( 15 downto 0 );
    m_axi_wvalid        : out STD_LOGIC;
    m_axi_bid           : in  STD_LOGIC_VECTOR ( 0 to 0);
    m_axi_rid           : in  STD_LOGIC_VECTOR ( 0 to 0);
    m_axi_buser         : in  STD_LOGIC_VECTOR ( 0 to 0);
    m_axi_ruser         : in  STD_LOGIC_VECTOR ( 0 to 0);
    
    
    rstn                : in STD_LOGIC;
    s_axi_araddr        : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_arprot        : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axi_arready       : out STD_LOGIC;
    s_axi_arvalid       : in STD_LOGIC;
    s_axi_awaddr        : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_awprot        : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axi_awready       : out STD_LOGIC;
    s_axi_awvalid       : in STD_LOGIC;
    s_axi_bready        : in STD_LOGIC;
    s_axi_bresp         : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_bvalid        : out STD_LOGIC;
    s_axi_rdata         : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_rready        : in STD_LOGIC;
    s_axi_rresp         : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_rvalid        : out STD_LOGIC;
    s_axi_wdata         : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_wready        : out STD_LOGIC;
    s_axi_wstrb         : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_wvalid        : in STD_LOGIC
    
 ) ;  
 end component action_wrapper  ;
  

  signal rstn                : std_logic;
 


    
begin


  rstn <= not rst;

action: component action_wrapper
  port map (
    clk  => clk_app,
    rstn => rstn,
     
    s_axi_araddr    =>  xk_d_i.m_axi_araddr , 
    s_axi_arprot    =>  xk_d_i.m_axi_arprot , 
    s_axi_arready   =>  kx_d_o.m_axi_arready, 
    s_axi_arvalid   =>  xk_d_i.m_axi_arvalid, 
    s_axi_awaddr    =>  xk_d_i.m_axi_awaddr , 
    s_axi_awprot    =>  (others => '0')     , 
    s_axi_awready   =>  kx_d_o.m_axi_awready, 
    s_axi_awvalid   =>  xk_d_i.m_axi_awvalid, 
    s_axi_bready    =>  xk_d_i.m_axi_bready , 
    s_axi_bresp     =>  kx_d_o.m_axi_bresp  , 
    s_axi_bvalid    =>  kx_d_o.m_axi_bvalid , 
    s_axi_rdata     =>  kx_d_o.m_axi_rdata  , 
    s_axi_rready    =>  xk_d_i.m_axi_rready , 
    s_axi_rresp     =>  kx_d_o.m_axi_rresp  , 
    s_axi_rvalid    =>  kx_d_o.m_axi_rvalid , 
    s_axi_wdata     =>  xk_d_i.m_axi_wdata  , 
    s_axi_wready    =>  kx_d_o.m_axi_wready , 
    s_axi_wstrb     =>  xk_d_i.m_axi_wstrb  , 
    s_axi_wvalid    =>  xk_d_i.m_axi_wvalid , 

    m_axi_araddr    => ks_d_o.s_axi_araddr  , 
    m_axi_arburst   => ks_d_o.s_axi_arburst , 
    m_axi_arcache   => ks_d_o.s_axi_arcache , 
    m_axi_arlen     => ks_d_o.s_axi_arlen   , 
    m_axi_arlock    => open, --ks_d_o.s_axi_arlock  , 
    m_axi_arprot    => ks_d_o.s_axi_arprot  , 
    m_axi_arqos     => ks_d_o.s_axi_arqos   , 
    m_axi_arready   => sk_d_i.s_axi_arready , 
    -- m_axi_arregion  => open,        -- ks_d_o.s_axi_arregio , 
    m_axi_arsize    => ks_d_o.s_axi_arsize  , 
    m_axi_arid(0)      => ks_d_o.s_axi_arid(0)  ,
    m_axi_aruser    => open , --ks_d_o.s_axi_aruser  , 
    m_axi_awid(0)      => ks_d_o.s_axi_awid(0)  ,
    m_axi_awuser    => open , --ks_d_o.s_axi_awuser  , 
    m_axi_arvalid   => ks_d_o.s_axi_arvalid , 
    m_axi_awaddr    => ks_d_o.s_axi_awaddr  , 
    m_axi_awburst   => ks_d_o.s_axi_awburst , 
    m_axi_awcache   => ks_d_o.s_axi_awcache , 
    m_axi_awlen     => ks_d_o.s_axi_awlen   , 
    m_axi_awlock    => open , -- ks_d_o.s_axi_awlock  , 
    m_axi_awprot    => ks_d_o.s_axi_awprot  , 
    m_axi_awqos     => ks_d_o.s_axi_awqos   , 
    m_axi_awready   => sk_d_i.s_axi_awready , 
    -- m_axi_awregion  => open,       -- ks_d_o.s_axi_awregio , 
    m_axi_awsize    => ks_d_o.s_axi_awsize  , 
    m_axi_awvalid   => ks_d_o.s_axi_awvalid , 
    m_axi_bready    => ks_d_o.s_axi_bready  , 
    m_axi_bresp     => sk_d_i.s_axi_bresp   , 
    m_axi_bvalid    => sk_d_i.s_axi_bvalid  , 
    m_axi_rdata     => sk_d_i.s_axi_rdata   , 
    m_axi_rlast     => sk_d_i.s_axi_rlast   , 
    m_axi_rready    => ks_d_o.s_axi_rready  , 
    m_axi_rresp     => sk_d_i.s_axi_rresp   , 
    m_axi_rvalid    => sk_d_i.s_axi_rvalid  , 
    m_axi_wdata     => ks_d_o.s_axi_wdata   , 
    m_axi_wlast     => ks_d_o.s_axi_wlast   , 
    m_axi_wready    => sk_d_i.s_axi_wready  , 
    m_axi_wstrb     => ks_d_o.s_axi_wstrb   , 
    m_axi_wvalid    => ks_d_o.s_axi_wvalid  ,
    m_axi_bid(0)    => sk_d_i.s_axi_bid(0)  ,
    m_axi_buser(0)  => '0'  ,
    m_axi_ruser(0)  => '0'  ,
    m_axi_rid(0)    => sk_d_i.s_axi_rid(0) ,
    m_axi_wuser     => open     
  );
  
END ARCHITECTURE;

