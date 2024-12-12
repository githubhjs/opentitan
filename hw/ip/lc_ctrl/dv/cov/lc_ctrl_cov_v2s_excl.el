// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Manual condition coverage exclusion to reach V2 requirement.
// Please remove this exclusion on V2S.
//==================================================
// This file contains the Excluded objects
// Generated By User: chencindy
// Format Version: 2
// Date: Mon Feb 14 15:45:11 2022
// ExclMode: default
//==================================================
CHECKSUM: "639577301 1160505329"
INSTANCE: tb.dut.u_lc_ctrl_fsm.u_lc_ctrl_state_transition
Condition 1 "1774000493" "((dec_lc_state_i[0] <= DecLcStScrap) && (trans_target_i[0] <= DecLcStScrap) && (dec_lc_state_i[1] <= DecLcStScrap) && (trans_target_i[1] <= DecLcStScrap)) 1 -1" (2 "1011")
Condition 1 "1774000493" "((dec_lc_state_i[0] <= DecLcStScrap) && (trans_target_i[0] <= DecLcStScrap) && (dec_lc_state_i[1] <= DecLcStScrap) && (trans_target_i[1] <= DecLcStScrap)) 1 -1" (4 "1110")
Condition 2 "698152782" "((lc_ctrl_pkg::TransTokenIdxMatrix[dec_lc_state_i[0]][trans_target_i[0]] != InvalidTokenIdx) || (lc_ctrl_pkg::TransTokenIdxMatrix[dec_lc_state_i[1]][trans_target_i[1]] != InvalidTokenIdx)) 1 -1" (2 "01")
Condition 2 "698152782" "((lc_ctrl_pkg::TransTokenIdxMatrix[dec_lc_state_i[0]][trans_target_i[0]] != InvalidTokenIdx) || (lc_ctrl_pkg::TransTokenIdxMatrix[dec_lc_state_i[1]][trans_target_i[1]] != InvalidTokenIdx)) 1 -1" (3 "10")
CHECKSUM: "905865107 3719120144"
INSTANCE: tb.dut.u_lc_ctrl_fsm
ANNOTATION: "VC_COV_UNR"
Condition 2 "4189173441" "(trans_invalid_error_o || token_mux_indices_inconsistent) 1 -1" (2 "01")
ANNOTATION: "VC_COV_UNR"
Condition 4 "3515114529" "(trans_invalid_error_o || token_mux_indices_inconsistent) 1 -1" (2 "01")
ANNOTATION: "VC_COV_UNR"
Condition 4 "3515114529" "(trans_invalid_error_o || token_mux_indices_inconsistent) 1 -1" (3 "10")