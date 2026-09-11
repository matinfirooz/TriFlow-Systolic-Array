package triflow_pkg;
    typedef enum logic [1:0] {
        DF_OUTPUT_STATIONARY = 2'd0,
        DF_WEIGHT_STATIONARY = 2'd1,
        DF_INPUT_STATIONARY  = 2'd2
    } dataflow_t;

    typedef enum logic [2:0] {
        ST_IDLE    = 3'd0,
        ST_CLEAR   = 3'd1,
        ST_PRELOAD = 3'd2,
        ST_COMPUTE = 3'd3,
        ST_DONE    = 3'd4
    } ctrl_state_t;
endpackage
