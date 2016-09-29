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

LIBRARY ieee; -- ibm, ibm_asic;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
--USE ieee.std_logic_arith.all;
--USE ibm.std_ulogic_support.all;
USE work.std_ulogic_function_support.all;
USE work.std_ulogic_unsigned.all;

USE work.afu_types.all;

ENTITY mmio IS
  GENERIC (
    -- Version register content
    IMP_VERSION_DAT        : std_ulogic_vector(63 DOWNTO 0) := x"0000_4650_1606_0100";
    APP_VERSION_DAT        : std_ulogic_vector(63 DOWNTO 0) := x"CAFE_0003_475A_4950";
    -- Time slice register
    TSR_RESET_VALUE        : std_ulogic_vector(63 DOWNTO 0) := x"0000_0000_0002_0000";
    -- DDCB Timeout register
    DTR_RESET_VALUE        : std_ulogic_vector(63 DOWNTO 0) := x"8000_0000_1575_2A00"
  );
  PORT (
    --
    -- pervasive
    ha_pclock              : IN  std_ulogic;
    afu_reset              : IN  std_ulogic;
    --
    -- debug (TODO: remove)
    ah_paren_mm_o          : OUT std_ulogic;
    --
    -- PSL IOs
    ha_mm_i                : IN  HA_MM_T;
    ah_mm_o                : OUT AH_MM_T;
    --
    -- CTRL MGR Interface
    cmm_e_i                : IN  CMM_E_T;
    mmc_e_o                : OUT MMC_E_T;
    --
    -- DMA Interface
    dmm_e_i                : IN  DMM_E_T;
    mmd_a_o                : OUT MMD_A_T;
    mmd_i_o                : OUT MMD_I_T;
    --
    -- AXI MASTER Interface
    xmm_d_i                : IN  XMM_D_T;
    mmx_d_o                : OUT MMX_D_T
  );
END mmio;

ARCHITECTURE mmio OF mmio IS
  --
  -- CONSTANT
--  CONSTANT TIMER_SIZE         : integer := 64;   -- Size of Timers in number of bits

  --
  -- TYPE
  TYPE REG64_ARRAY_T IS ARRAY (natural RANGE <>) OF std_ulogic_vector(63 DOWNTO 0);
--  TYPE REG32_ARRAY_T IS ARRAY (natural RANGE <>) OF std_ulogic_vector(31 DOWNTO 0);

  --
  -- ATTRIBUTE

  --
  -- SIGNAL
  SIGNAL ha_mm_q0                             : HA_MM_T;
  SIGNAL ha_mm_r_q0                           : HA_MM_T;
  SIGNAL ha_mm_r_q                            : HA_MM_T;
  SIGNAL ha_mm_w_q0                           : HA_MM_T;
  SIGNAL ha_mm_w_q                            : HA_MM_T;
  SIGNAL ah_mm_q                              : AH_MM_T;
  SIGNAL ah_mm_read_ack_q                     : std_ulogic;
  SIGNAL ah_mm_write_ack_q0                   : std_ulogic;
  SIGNAL ah_mm_write_ack_q                    : std_ulogic;
  SIGNAL xmm_ack_q                            : std_ulogic;
  SIGNAL mmio_read_action_addr_q0             : std_ulogic;
  SIGNAL mmio_read_alignment_error_q          : std_ulogic;
  SIGNAL mmio_read_invalid_address_q          : std_ulogic;
  SIGNAL mmio_read_master_access_q            : std_ulogic;
  SIGNAL mmio_read_action_access_q            : std_ulogic;
  SIGNAL mmio_read_cfg_access_q               : std_ulogic;
  SIGNAL mmio_read_access_q                   : std_ulogic;
  SIGNAL mmio_read_reg_offset_q               : integer RANGE 0 TO 15;
  SIGNAL mmio_read_data_q0                    : std_ulogic_vector(63 DOWNTO 0);
  SIGNAL mmio_read_datapar_q0                 : std_ulogic;
  SIGNAL mmio_read_ack_q0                     : std_ulogic;
  SIGNAL mmio_read_data_q                     : std_ulogic_vector(63 DOWNTO 0);
  SIGNAL mmio_read_datapar_q                  : std_ulogic;
  SIGNAL mmio_read_ack_q                      : std_ulogic;
  SIGNAL mmio_read_action_outstanding_q       : std_ulogic;
  SIGNAL mmio_master_read_q0                  : std_ulogic;
  SIGNAL mmio_master_read_q                   : std_ulogic;
  SIGNAL mmio_write_parity_error_q            : std_ulogic;
  SIGNAL mmio_write_action_addr_q0            : std_ulogic;
  SIGNAL mmio_write_alignment_error_q         : std_ulogic;
  SIGNAL mmio_write_invalid_address_q         : std_ulogic;
  SIGNAL mmio_write_master_access_q           : std_ulogic;
  SIGNAL mmio_write_action_access_q           : std_ulogic;
  SIGNAL mmio_write_cfg_access_q              : std_ulogic;
  SIGNAL mmio_write_access_q                  : std_ulogic;
  SIGNAL mmio_write_reg_offset_q              : integer RANGE 0 TO 15;
  SIGNAL mmio_cfg_space_access_q              : boolean;
  SIGNAL afu_des                              : REG64_ARRAY_T(15 DOWNTO 0);
  SIGNAL afu_des_p                            : std_ulogic_vector(15 DOWNTO 0);
  SIGNAL afu_cfg                              : REG64_ARRAY_T(AFU_CFG_SPACE_SIZE-1 DOWNTO 0);
  SIGNAL afu_cfg_p                            : std_ulogic_vector(AFU_CFG_SPACE_SIZE-1 DOWNTO 0);
  SIGNAL ctrl_mgr_err_q                       : std_ulogic_vector(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL mmio_err_q                           : std_ulogic_vector(31 DOWNTO 0) := (OTHERS => '0');
  SIGNAL non_fatal_master_rd_errors_q         : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL non_fatal_master_wr_errors_q         : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL non_fatal_master_errors_reset_q      : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL non_fatal_slave_rd_errors_q          : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL non_fatal_slave_wr_errors_q          : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL non_fatal_slave_errors_reset_q       : std_ulogic_vector(NFE_L DOWNTO NFE_R);
  SIGNAL mmc_e_q                              : MMC_E_T;
  SIGNAL mm_e_q                               : MM_E_T := ('0', '0',(OTHERS => '0'));
  SIGNAL dbg_regs_q                           : REG64_ARRAY_T(15 DOWNTO 0);
  SIGNAL dbg_regs_par_q                       : std_ulogic_vector(15 DOWNTO 0);

BEGIN

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ******************************************************
-- ***** REGISTER READ LOGIC                        *****
-- ******************************************************
--
-- Note: The AFU is not supporting 32 bit MMIO reads
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- AFU Descriptor Space
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  -- Note: The values of this constants are specified in afu_types
  --
  afu_des(0)  <= AFU_DES_INI.NUM_INTS_PER_PROCESS &  -- register offset x"00"
                 AFU_DES_INI.NUM_OF_PROCESSES     &
                 AFU_DES_INI.NUM_OF_AFU_CRS       &
                 AFU_DES_INI.REG_PROG_MODEL;
  afu_des(1)  <= x"0000_0000_0000_0000";             -- register offset x"08"
  afu_des(2)  <= x"0000_0000_0000_0000";             -- register offset x"10"
  afu_des(3)  <= x"0000_0000_0000_0000";             -- register offset x"18"
  afu_des(4)  <= x"00" &                             -- register offset x"20"
                 AFU_DES_INI.AFU_CR_LEN;
  afu_des(5)  <= AFU_DES_INI.AFU_CR_OFFSET;          -- register offset x"28"
  afu_des(6)  <= AFU_DES_INI.PERPROCESSPSA_CONTROL & -- register offset x"30"
                 AFU_DES_INI.PERPROCESSPSA_LENGTH;
  afu_des(7)  <= AFU_DES_INI.PERPROCESSPSA_OFFSET;   -- register offset x"38"
  afu_des(8)  <= x"00" &                             -- register offset x"40"
                 AFU_DES_INI.AFU_EB_LEN;
  afu_des(9)  <= AFU_DES_INI.AFU_EB_OFFSET;          -- register offset x"48"
  afu_des(10) <= x"0000_0000_0000_0000";             -- register offset x"50"
  afu_des(11) <= x"0000_0000_0000_0000";             -- register offset x"58"
  afu_des(12) <= x"0000_0000_0000_0000";             -- register offset x"60"
  afu_des(13) <= x"0000_0000_0000_0000";             -- register offset x"68"
  afu_des(14) <= x"0000_0000_0000_0000";             -- register offset x"70"
  afu_des(15) <= x"0000_0000_0000_0000";             -- register offset x"78"

  afu_des_p_gen: FOR i IN 0 TO 15 GENERATE
    afu_des_p(i) <= parity_gen_odd(afu_des(i));
  END GENERATE afu_des_p_gen;


  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- AFU Config Space
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  -- Note: The values of this constants are specified in afu_types
  --
  afu_cfg(0)   <= AFU_CFG_INI.AFU_VENDOR_ID & AFU_CFG_INI.AFU_DEVICE_ID & x"0000_0000";
  afu_cfg_p(0) <= parity_gen_odd(afu_cfg(0));
  afu_cfg(1)   <= AFU_CFG_INI.AFU_REVISION_ID & AFU_CFG_INI.AFU_CLASS_CODE & x"0000_0000";
  afu_cfg_p(1) <= parity_gen_odd(afu_cfg(1));

  afu_cfg_p_gen: FOR i IN 2 TO AFU_CFG_SPACE_SIZE-1 GENERATE
    afu_cfg(i)   <= (OTHERS => '0');
    afu_cfg_p(i) <= '1';
  END GENERATE afu_cfg_p_gen;


  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- AFU Error Output to CTRL Manager
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  mmc_e_o <= mmc_e_q;


  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- MMIO READ PROCESS
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  mmio_r : PROCESS (ha_pclock)
  BEGIN
    IF (rising_edge(ha_pclock)) THEN
      IF afu_reset = '1' THEN
        non_fatal_master_rd_errors_q   <= (OTHERS => '0');
        non_fatal_slave_rd_errors_q    <= (OTHERS => '0');
        mmio_master_read_q0            <= '0';
        mmio_master_read_q             <= '0';
        mmio_read_data_q0              <= (OTHERS => '0');
        mmio_read_datapar_q0           <= '1';
        mmio_read_ack_q0               <= '0';
        mmio_read_data_q               <= (OTHERS => '0');
        mmio_read_datapar_q            <= '1';
        mmio_read_ack_q                <= '0';
        ah_mm_q.data                   <= (OTHERS => '0');
        ah_mm_q.datapar                <= '1';
        ah_mm_read_ack_q               <= '0';
        mmio_read_action_outstanding_q <= '0';

        mm_e_q.rd_data_parity_err    <= (OTHERS => '0');

      ELSE
        --
        -- default
        --
        non_fatal_master_rd_errors_q   <= (OTHERS => '0');
        non_fatal_slave_rd_errors_q    <= (OTHERS => '0');
        mmio_master_read_q0            <= mmio_master_read_q0;
        mmio_master_read_q             <= mmio_master_read_q0;
        mmio_read_data_q0              <= (OTHERS => '1');
        mmio_read_data_q               <= mmio_read_data_q0;
        mmio_read_datapar_q0           <= '1';
        mmio_read_datapar_q            <= mmio_read_datapar_q0;
        mmio_read_ack_q0               <= '0';
        mmio_read_ack_q                <= mmio_read_ack_q0;
        ah_mm_q.data                   <= mmio_read_data_q;
        ah_mm_q.datapar                <= mmio_read_datapar_q;
        ah_mm_read_ack_q               <= mmio_read_ack_q;
        mmio_read_action_outstanding_q <= mmio_read_action_outstanding_q;

        mm_e_q.rd_data_parity_err      <= (OTHERS => '0');

        --
        -- MMIO Read alignment error
        --
        IF mmio_read_alignment_error_q = '1' THEN
          non_fatal_master_rd_errors_q(NFE_MMIO_BAD_RD_AL) <= mmio_read_master_access_q;
          non_fatal_slave_rd_errors_q(NFE_MMIO_BAD_RD_AL)  <= NOT mmio_read_master_access_q;
          -- acknowledge read request
          ah_mm_read_ack_q                                 <= '1';
        END IF;

        --
        -- MMIO Read invalid address error
        --
        IF mmio_read_invalid_address_q = '1' THEN
          non_fatal_master_rd_errors_q(NFE_INV_RD_ADDRESS) <= mmio_read_master_access_q;
          non_fatal_slave_rd_errors_q(NFE_INV_RD_ADDRESS)  <= NOT mmio_read_master_access_q;
          -- acknowledge read request
          ah_mm_read_ack_q                                 <= '1';
        END IF;

        --
        -- MMIO CFG READ
        --
        IF mmio_read_cfg_access_q = '1' THEN
          -- acknowledge read request
          ah_mm_read_ack_q  <= '1';

          CASE to_integer(unsigned(ha_mm_r_q.ad(13 DOWNTO 5))) IS
            --
            -- AFU DESCRIPTOR READ
            --
            WHEN AFU_DESCRIPTOR_BASE =>
              IF ha_mm_r_q.dw = '1' THEN
                ah_mm_q.data    <= afu_des(mmio_read_reg_offset_q);
                ah_mm_q.datapar <= afu_des_p(mmio_read_reg_offset_q);
              ELSE
                non_fatal_master_rd_errors_q(NFE_MMIO_BAD_RD_AL) <= mmio_read_master_access_q;
                non_fatal_slave_rd_errors_q(NFE_MMIO_BAD_RD_AL)  <= NOT mmio_read_master_access_q;
              END IF;

            --
            -- AFU CONFIG SPACE READ (lower 128 byte)
            --
            WHEN AFU_CFG_SPACE0_BASE =>
              IF mmio_read_reg_offset_q < AFU_CFG_SPACE_SIZE THEN
                IF ha_mm_r_q.dw = '1' THEN
                  ah_mm_q.data    <= afu_cfg(mmio_read_reg_offset_q);
                  ah_mm_q.datapar <= afu_cfg_p(mmio_read_reg_offset_q);
                ELSIF ha_mm_r_q.ad(0) = '0' THEN
                  ah_mm_q.data    <= afu_cfg(mmio_read_reg_offset_q)(63 DOWNTO 32) & afu_cfg(mmio_read_reg_offset_q)(63 DOWNTO 32);
                  ah_mm_q.datapar <= '1';
                ELSE
                  ah_mm_q.data    <= afu_cfg(mmio_read_reg_offset_q)(31 DOWNTO 0) & afu_cfg(mmio_read_reg_offset_q)(31 DOWNTO 0);
                  ah_mm_q.datapar <= '1';
                END IF;
              ELSE
                ah_mm_q.data    <= (OTHERS => '0');
                ah_mm_q.datapar <= '1';
              END IF;

            --
            -- AFU CONFIG SPACE READ (upper 128 byte - currently unused)
            --
            WHEN AFU_CFG_SPACE1_BASE =>
              ah_mm_q.data    <= (OTHERS => '0');
              ah_mm_q.datapar <= '1';

--            --
--            -- AFU FIR REGISTER READ
--            --
--            WHEN FIR_REG_BASE =>
--              IF mmio_read_reg_offset_q < fir_reg_q'LENGTH THEN
--                IF ha_mm_r_q.dw = '1' THEN            -- double word access
--                  ah_mm_q.data(63 DOWNTO 58) <= (OTHERS => '0');
--                  ah_mm_q.data(57 DOWNTO 34) <= ha_mm_r_q.ad(23 DOWNTO 0);
--                  ah_mm_q.data(33 DOWNTO 32) <= (OTHERS => '0');
--                  ah_mm_q.data(31 DOWNTO  0) <= fir_reg_q(mmio_read_reg_offset_q);
--                  ah_mm_q.datapar            <= fir_reg_par_q(mmio_read_reg_offset_q) XNOR parity_gen_odd(ha_mm_r_q.ad(23 DOWNTO 1));
--                ELSIF ha_mm_r_q.ad(0) = '0' THEN
--                  ah_mm_q.data    <= fir_reg_q(mmio_read_reg_offset_q) & fir_reg_q(mmio_read_reg_offset_q);
--                  ah_mm_q.datapar <= '1';
--                ELSE
--                  ah_mm_q.data(63 DOWNTO 58) <= (OTHERS => '0');
--                  ah_mm_q.data(57 DOWNTO 35) <= ha_mm_r_q.ad(23 DOWNTO 1);
--                  ah_mm_q.data(34 DOWNTO 26) <= (OTHERS => '0');
--                  ah_mm_q.data(25 DOWNTO  3) <= ha_mm_r_q.ad(23 DOWNTO 1);
--                  ah_mm_q.data( 2 DOWNTO  0) <= (OTHERS => '0');
--                  ah_mm_q.datapar <= '1';
--                END IF;
--              ELSE
--                -- unused error buffer space:
--                ah_mm_q.data(63 DOWNTO 0) <= (OTHERS => '0');
--                ah_mm_q.datapar           <= '1';
--              END IF;

            WHEN OTHERS =>
              IF ha_mm_r_q.ad(13 DOWNTO 10) = "0001" THEN
                -- error buffer space (unused)
                ah_mm_q.data(63 DOWNTO 0) <= (OTHERS => '0');
                ah_mm_q.datapar           <= '1';
              ELSE
                -- invalid address
                non_fatal_master_rd_errors_q(NFE_INV_RD_ADDRESS) <= mmio_read_master_access_q;
                non_fatal_slave_rd_errors_q(NFE_INV_RD_ADDRESS)  <= NOT mmio_read_master_access_q;
              END IF;
          END CASE;

        END IF;     -- cfg read (mmio_read_cfg_access_q = '1')


        --
        -- MMIO READ
        -- valid read request that is not targeting the action
        --
        IF (mmio_read_access_q AND NOT mmio_read_action_access_q) = '1' THEN
          -- acknowledge read request
          mmio_read_ack_q0     <= '1';
          mmio_master_read_q0  <= mmio_read_master_access_q;

          CASE to_integer(unsigned(ha_mm_r_q.ad(13 DOWNTO 5))) IS
            -- for DEBUG (TODO: remove)
            --
            -- AFU DEBUG REGISTER READ
            --
            WHEN DEBUG_REG_BASE =>
              mmio_read_data_q0    <= dbg_regs_q(mmio_read_reg_offset_q);
              mmio_read_datapar_q0 <= dbg_regs_par_q(mmio_read_reg_offset_q);

            WHEN OTHERS =>
              -- invalid address
              non_fatal_master_rd_errors_q(NFE_INV_RD_ADDRESS) <= mmio_read_master_access_q;
              non_fatal_slave_rd_errors_q(NFE_INV_RD_ADDRESS)  <= NOT mmio_read_master_access_q;
          END CASE;

        END IF;                                   -- (mmio_read_access_q and not mmio_read_action_access_q) = '1'

        IF (mmio_read_action_access_q AND NOT mmio_read_alignment_error_q) = '1' THEN
          mmio_read_action_outstanding_q <= '1';
        END IF;

        IF (xmm_d_i.ack AND mmio_read_action_outstanding_q) = '1' THEN
          ah_mm_q.data                   <= xmm_d_i.data & xmm_d_i.data; -- duplicate the AXI 32 bit bus on the 64 bit PSL interface
          ah_mm_q.datapar                <= '1';                         -- this leads to a constant odd parity bit of '1'
          mmio_read_action_outstanding_q <= '0';
        END IF;

      END IF;                                     -- afu_reset = '1'
    END IF;                                       -- rising_edge(ha_pclock)
  END PROCESS mmio_r;


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ******************************************************
-- ***** REGISER WRITE LOGIC                        *****
-- ******************************************************
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- MMIO WRITE PROCESS
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  mmio_w : PROCESS (ha_pclock)
--    VARIABLE ah_paren_mm_v        : std_ulogic;                    -- for DEBUG (TODO: remove)
  BEGIN
    IF (rising_edge(ha_pclock)) THEN
      IF afu_reset = '1' THEN
        --
        --reset registers
        dbg_regs_q                      <= (OTHERS => (OTHERS => '0'));
        dbg_regs_par_q                  <= (OTHERS => '1');

        mm_e_q.wr_data_parity_err       <= '0';

        non_fatal_master_wr_errors_q    <= (OTHERS => '0');
        non_fatal_master_errors_reset_q <= (OTHERS => '0');
        non_fatal_slave_wr_errors_q     <= (OTHERS => '0');
        non_fatal_slave_errors_reset_q  <= (OTHERS => '0');

      ELSE
        --
        -- default
        dbg_regs_q                      <= dbg_regs_q;
        dbg_regs_par_q                  <= dbg_regs_par_q;

        mm_e_q.wr_data_parity_err       <= '0';

        non_fatal_master_wr_errors_q    <= (OTHERS => '0');
        non_fatal_master_errors_reset_q <= (OTHERS => '0');
        non_fatal_slave_wr_errors_q     <= (OTHERS => '0');
        non_fatal_slave_errors_reset_q  <= (OTHERS => '0');

        --
        -- MMIO Write parity error
        --
        IF (mmio_write_parity_error_q = '1') THEN
          mm_e_q.wr_data_parity_err <= '1';
        END IF;

        --
        -- MMIO Write alignment error
        --
        IF mmio_write_alignment_error_q = '1' THEN
          non_fatal_master_wr_errors_q(NFE_MMIO_BAD_WR_AL) <= mmio_write_master_access_q;
          non_fatal_slave_wr_errors_q(NFE_MMIO_BAD_WR_AL)  <= NOT mmio_write_master_access_q;
        END IF;

        --
        -- MMIO Write invalid address error
        --
        IF mmio_write_invalid_address_q = '1' THEN
          non_fatal_master_wr_errors_q(NFE_INV_WR_ADDRESS) <= mmio_write_master_access_q;
          non_fatal_slave_wr_errors_q(NFE_INV_WR_ADDRESS)  <= NOT mmio_write_master_access_q;
        END IF;

        --
        -- MMIO CFG WRITE (not supported for non cfg space access - will ack and raise non fatal error)
        --
        IF mmio_write_cfg_access_q = '1' AND NOT mmio_cfg_space_access_q THEN
          non_fatal_master_wr_errors_q(NFE_CFG_WR_ACCESS) <= mmio_write_master_access_q;
          non_fatal_slave_wr_errors_q(NFE_CFG_WR_ACCESS)  <= NOT mmio_write_master_access_q;
        END IF;

        --
        -- MMIO READ
        -- valid write request that is not targeting the action
        --
        IF (mmio_write_access_q AND NOT mmio_write_action_access_q) = '1' THEN
          CASE to_integer(unsigned(ha_mm_w_q.ad(13 DOWNTO 5))) IS
--            --
--            -- AFU FIR REGISTER WRITE (Reset on One)
--            --
--            WHEN FIR_REG_BASE =>
--              IF mmio_write_reg_offset_q < fir_reg_q'LENGTH THEN
--                fir_write_req_q <= '1';
--              ELSE
--                -- invalid address
--                non_fatal_master_wr_errors_q(NFE_INV_WR_ADDRESS) <= mmio_write_master_access_q;
--                non_fatal_slave_wr_errors_q(NFE_INV_WR_ADDRESS)  <= NOT mmio_write_master_access_q;
--              END IF;

            -- for DEBUG (TODO: remove)
            --
            -- AFU DEBUG REGISTER WRITE
            --
            WHEN DEBUG_REG_BASE =>
              IF mmio_write_master_access_q = '1' THEN
                dbg_regs_q(mmio_write_reg_offset_q)     <= ha_mm_w_q.data;
                dbg_regs_par_q(mmio_write_reg_offset_q) <= ha_mm_w_q.datapar;
              ELSE
                -- invalid (non-master) access
                non_fatal_slave_wr_errors_q(NFE_INV_WR_ACCESS) <= '1';
              END IF;

            WHEN OTHERS =>
              -- invalid address
              non_fatal_master_wr_errors_q(NFE_INV_WR_ADDRESS) <= mmio_write_master_access_q;
              non_fatal_slave_wr_errors_q(NFE_INV_WR_ADDRESS)  <= NOT mmio_write_master_access_q;
          END CASE;

        END IF;                                   -- (mmio_write_access_q and not mmio_write_action_access_q) = '1'

      END IF;                                     -- afu_reset = '1'
    END IF;                                       -- rising_edge(ha_pclock)
  END PROCESS mmio_w;


  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- MMIO FIR PROCESS
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  mmio_fir : PROCESS (ha_pclock)
  BEGIN
    IF rising_edge(ha_pclock) THEN
      -- Capture Error bits (TODO: Specification of bits)
      -- ================================================
      --
      -- Ctrl Mgr
      ctrl_mgr_err_q <= (CTRLMGR_CTRL_FSM_ERR   => cmm_e_i.ctrl_fsm_err,
                         CTRLMGR_COM_PARITY_ERR => cmm_e_i.com_parity_err,
                         CTRLMGR_EA_PARITY_ERR  => cmm_e_i.ea_parity_err,
                         OTHERS => '0');
      --
      -- MMIO
      mmio_err_q    <= (MMIO_DATA_PARITY_ERR   => mm_e_q.wr_data_parity_err,
                        MMIO_ADDR_PARITY_ERR   => mm_e_q.wr_addr_parity_err,
                        MMIO_DDCBQ_SP_RD_ERR   => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_SP_RD_ERR),
                        MMIO_DDCBQ_CFG_RD_ERR  => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_CFG_RD_ERR),
                        MMIO_DDCBQ_ST_RD_ERR   => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_ST_RD_ERR),
                        MMIO_DDCBQ_NFE_RD_ERR  => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_NFE_RD_ERR),
                        MMIO_DDCBQ_SEQI_RD_ERR => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_SEQI_RD_ERR),
                        MMIO_DDCBQ_SEQL_RD_ERR => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_SEQL_RD_ERR),
                        MMIO_DDCBQ_DMAE_RD_ERR => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_DMAE_RD_ERR),
                        MMIO_DDCBQ_WT_RD_ERR   => mm_e_q.rd_data_parity_err(MMIO_DDCBQ_WT_RD_ERR),
                        OTHERS => '0');
      --
      -- AFU ERRORS
      mmc_e_q.error                  <= (OTHERS => '0');

    END IF;
  END PROCESS mmio_fir;

  --
  -- MMIO FIR ASSERTS
  --
  ASSERT mm_e_q.wr_data_parity_err             = '0' REPORT "FIR: MMIO ha_mm_i data parity error" SEVERITY FIR_MSG_LEVEL;
  ASSERT mm_e_q.wr_addr_parity_err             = '0' REPORT "FIR: MMIO ha_mm_i address parity error" SEVERITY FIR_MSG_LEVEL;
  ASSERT or_reduce(mm_e_q.rd_data_parity_err)  = '0' REPORT "FIR: MMIO memory read parity error" SEVERITY FIR_MSG_LEVEL;


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
---- ******************************************************
---- ***** MISC                                       *****
---- ******************************************************
----
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --  Output Connection
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
    --
    -- AH_MM
    --
    ah_mm_o.ack     <= ah_mm_read_ack_q OR ah_mm_write_ack_q OR xmm_ack_q;
    ah_mm_o.data    <= ah_mm_q.data;
    ah_mm_o.datapar <= ah_mm_q.datapar; -- XOR mm_i_q.inject_read_rsp_parity_error;  -- toggle parity iff inject_read_rsp_parity_error is set to '1';

    --
    -- MMX
    --
    mmx_d_o.addr(31 DOWNTO 16) <= (OTHERS => '0');
    mmx_d_o.addr(15 DOWNTO  2) <= ha_mm_w_q.ad(13 DOWNTO 0);
    mmx_d_o.addr( 1 DOWNTO  0) <= (OTHERS => '0');
    mmx_d_o.data               <= ha_mm_w_q.data(31 DOWNTO 0);
    mmx_d_o.wr_strobe          <= mmio_write_action_access_q AND NOT mmio_write_alignment_error_q;
    mmx_d_o.rd_strobe          <= mmio_read_action_access_q AND NOT mmio_read_alignment_error_q;

  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --  Host Interface
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  host_interface : PROCESS (ha_pclock)
  BEGIN
    IF (rising_edge(ha_pclock)) THEN
      IF afu_reset = '1' THEN
        ha_mm_q0                            <= ('0', '0', '0', '0', (OTHERS => '0'), '0', (OTHERS => '0'), '0');
        ha_mm_r_q0                          <= ('0', '0', '0', '0', (OTHERS => '0'), '0', (OTHERS => '0'), '0');
        ha_mm_r_q                           <= ('0', '0', '0', '0', (OTHERS => '0'), '0', (OTHERS => '0'), '0');
        ha_mm_w_q0                          <= ('0', '0', '0', '0', (OTHERS => '0'), '0', (OTHERS => '0'), '0');
        ha_mm_w_q                           <= ('0', '0', '0', '0', (OTHERS => '0'), '0', (OTHERS => '0'), '0');

        mmio_read_action_addr_q0            <= '0';
        mmio_read_alignment_error_q         <= '0';
        mmio_read_invalid_address_q         <= '0';
        mmio_read_cfg_access_q              <= '0';
        mmio_read_access_q                  <= '0';
        mmio_read_reg_offset_q              <=  0;
        mmio_write_parity_error_q           <= '0';
        mmio_write_action_addr_q0           <= '0';
        mmio_write_alignment_error_q        <= '0';
        mmio_write_invalid_address_q        <= '0';
        mmio_write_cfg_access_q             <= '0';
        mmio_write_access_q                 <= '0';
        mmio_write_reg_offset_q             <=  0;
        mmio_cfg_space_access_q             <= FALSE;
        mm_e_q.wr_addr_parity_err           <= '0';

        ah_mm_write_ack_q0                  <= '0';
        ah_mm_write_ack_q                   <= '0';
        mmio_read_master_access_q           <= '0';
        mmio_read_action_access_q           <= '0';
        mmio_write_master_access_q          <= '0';
        mmio_write_action_access_q          <= '0';

      ELSE
        ha_mm_q0             <= ha_mm_i;
        ha_mm_r_q0           <= ha_mm_i;
        ha_mm_r_q            <= ha_mm_r_q0;
        ha_mm_w_q0           <= ha_mm_i;
        ha_mm_w_q0.datapar   <= ha_mm_i.datapar; -- XOR mm_i_q.inject_write_parity_error;  -- toggle parity iff inject_write_parity_error is set to '1'
        ha_mm_w_q            <= ha_mm_w_q0;

        --
        -- MMIO READ ACCESS
        --
        mmio_read_action_addr_q0     <= ha_mm_i.ad(ACTION_BIT) AND NOT or_reduce(ha_mm_i.ad(23 DOWNTO MASTER_BOUNDARY));
        mmio_read_alignment_error_q  <= ha_mm_r_q0.valid AND ha_mm_r_q0.rnw AND
                                        ((ha_mm_r_q0.dw AND (ha_mm_r_q0.ad(0) OR mmio_read_action_addr_q0)) OR
                                         NOT (ha_mm_r_q0.dw OR ha_mm_r_q0.cfg OR mmio_read_action_addr_q0));
        mmio_read_invalid_address_q  <= ha_mm_r_q0.valid AND ha_mm_r_q0.rnw AND (NOT ha_mm_r_q0.cfg) AND
                                        ha_mm_r_q0.ad(23) AND or_reduce(ha_mm_r_q0.ad(22 DOWNTO 14));
        mmio_read_cfg_access_q       <= ha_mm_r_q0.valid AND ha_mm_r_q0.rnw AND ha_mm_r_q0.cfg;
        mmio_read_access_q           <= ha_mm_r_q0.valid AND ha_mm_r_q0.rnw AND (NOT ha_mm_r_q0.cfg) AND NOT ha_mm_r_q0.ad(0) AND
                                        NOT (ha_mm_r_q0.ad(23) AND or_reduce(ha_mm_r_q0.ad(22 DOWNTO 14)));
        mmio_read_reg_offset_q       <= to_integer(unsigned(ha_mm_r_q0.ad(4 DOWNTO 1)));
        mmio_read_master_access_q    <= mmio_read_master_access_q;
        mmio_read_action_access_q    <= '0';
        IF ha_mm_r_q0.valid = '1' AND (ha_mm_r_q0.rnw = '1') THEN
          mmio_read_master_access_q <= NOT or_reduce(ha_mm_q0.ad(23 DOWNTO MASTER_BOUNDARY));
          mmio_read_action_access_q <= mmio_read_action_addr_q0;
        END IF;

        --
        -- MMIO WRITE ACCESS
        --
        mmio_write_parity_error_q    <= ha_mm_w_q0.valid AND (NOT ha_mm_w_q0.rnw) AND (ha_mm_w_q0.datapar XOR parity_gen_odd(ha_mm_w_q0.data));
        mmio_write_action_addr_q0    <= ha_mm_i.ad(ACTION_BIT) AND NOT or_reduce(ha_mm_i.ad(23 DOWNTO MASTER_BOUNDARY));
        mmio_write_alignment_error_q <= ha_mm_w_q0.valid AND ha_mm_w_q0.rnw AND
                                        ((ha_mm_w_q0.dw AND (ha_mm_w_q0.ad(0) OR mmio_write_action_addr_q0)) OR
                                         NOT (ha_mm_w_q0.dw OR ha_mm_w_q0.cfg OR mmio_write_action_addr_q0));
        mmio_write_invalid_address_q <= ha_mm_w_q0.valid AND (NOT ha_mm_w_q0.rnw) AND (NOT ha_mm_w_q0.cfg) AND
                                        ha_mm_w_q0.ad(23) AND or_reduce(ha_mm_w_q0.ad(22 DOWNTO 14));
        mmio_write_cfg_access_q      <= ha_mm_r_q0.valid AND (NOT ha_mm_r_q0.rnw) AND ha_mm_r_q0.cfg;
        mmio_write_access_q          <= ha_mm_w_q0.valid AND (NOT ha_mm_w_q0.rnw) AND (NOT ha_mm_w_q0.cfg) AND (NOT ha_mm_w_q0.ad(0)) AND
                                        (ha_mm_w_q0.datapar XNOR parity_gen_odd(ha_mm_w_q0.data)) AND
                                        NOT (ha_mm_w_q0.ad(23) AND or_reduce(ha_mm_w_q0.ad(22 DOWNTO 14)));
        mmio_write_reg_offset_q      <= to_integer(unsigned(ha_mm_w_q0.ad(4 DOWNTO 1)));
        mmio_write_master_access_q   <= mmio_write_master_access_q;
        mmio_write_action_access_q   <= '0';
        IF ha_mm_r_q0.valid = '1' AND (ha_mm_w_q0.rnw = '0') THEN
          mmio_write_master_access_q <= NOT or_reduce(ha_mm_q0.ad(23 DOWNTO MASTER_BOUNDARY));
          mmio_write_action_access_q <= mmio_write_action_addr_q0;
        END IF;

        mmio_cfg_space_access_q      <= to_integer(unsigned(ha_mm_q0.ad(13 DOWNTO 6) & '0')) = AFU_CFG_SPACE0_BASE;

        -- acknowledge write request
        ah_mm_write_ack_q0           <= ha_mm_w_q0.valid AND (NOT ha_mm_w_q0.rnw);
        ah_mm_write_ack_q            <= (ah_mm_write_ack_q0 AND NOT mmio_write_action_access_q);

        mm_e_q.wr_addr_parity_err    <= (ha_mm_q0.adpar XOR parity_gen_odd(ha_mm_q0.ad)) AND ha_mm_q0.valid ;

      END IF;
    END IF;
  END PROCESS host_interface;


  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --  AXI Master Interface
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  --
  axi_master_interface : PROCESS (ha_pclock)
  BEGIN
    IF (rising_edge(ha_pclock)) THEN
      IF afu_reset = '1' THEN
        xmm_ack_q <= '0';
      ELSE
        -- acknowledge from AXI master
        xmm_ack_q <= xmm_d_i.ack;
      END IF;
    END IF;
  END PROCESS axi_master_interface;

END ARCHITECTURE;
