# -*- encoding : ascii-8bit -*-

module Ethereum
  class Opcodes

    TABLE = {
      # schema: [op, ins, outs, gas]
      0x00 => [:STOP, 0, 0, 0],
      0x01 => [:ADD, 2, 1, 3],
      0x02 => [:MUL, 2, 1, 5],
      0x03 => [:SUB, 2, 1, 3],
      0x04 => [:DIV, 2, 1, 5],
      0x05 => [:SDIV, 2, 1, 5],
      0x06 => [:MOD, 2, 1, 5],
      0x07 => [:SMOD, 2, 1, 5],
      0x08 => [:ADDMOD, 3, 1, 8],
      0x09 => [:MULMOD, 3, 1, 8],
      0x0a => [:EXP, 2, 1, 10],
      0x0b => [:SIGNEXTEND, 2, 1, 5],
      0x10 => [:LT, 2, 1, 3],
      0x11 => [:GT, 2, 1, 3],
      0x12 => [:SLT, 2, 1, 3],
      0x13 => [:SGT, 2, 1, 3],
      0x14 => [:EQ, 2, 1, 3],
      0x15 => [:ISZERO, 1, 1, 3],
      0x16 => [:AND, 2, 1, 3],
      0x17 => [:OR, 2, 1, 3],
      0x18 => [:XOR, 2, 1, 3],
      0x19 => [:NOT, 1, 1, 3],
      0x1a => [:BYTE, 2, 1, 3],
      0x20 => [:SHA3, 2, 1, 30],
      0x30 => [:ADDRESS, 0, 1, 2],
      0x31 => [:BALANCE, 1, 1, 20],
      0x32 => [:ORIGIN, 0, 1, 2],
      0x33 => [:CALLER, 0, 1, 2],
      0x34 => [:CALLVALUE, 0, 1, 2],
      0x35 => [:CALLDATALOAD, 1, 1, 3],
      0x36 => [:CALLDATASIZE, 0, 1, 2],
      0x37 => [:CALLDATACOPY, 3, 0, 3],
      0x38 => [:CODESIZE, 0, 1, 2],
      0x39 => [:CODECOPY, 3, 0, 3],
      0x3a => [:GASPRICE, 0, 1, 2],
      0x3b => [:EXTCODESIZE, 1, 1, 20],
      0x3c => [:EXTCODECOPY, 4, 0, 20],
      0x3d => [:MCOPY, 3, 0, 0],
      0x40 => [:BLOCKHASH, 1, 1, 20],
      0x41 => [:COINBASE, 0, 1, 2],
      0x42 => [:TIMESTAMP, 0, 1, 2],
      0x43 => [:NUMBER, 0, 1, 2],
      0x44 => [:DIFFICULTY, 0, 1, 2],
      0x45 => [:GASLIMIT, 0, 1, 2],
      0x50 => [:POP, 1, 0, 2],
      0x51 => [:MLOAD, 1, 1, 3],
      0x52 => [:MSTORE, 2, 0, 3],
      0x53 => [:MSTORE8, 2, 0, 3],
      0x54 => [:SLOAD, 1, 1, 50],
      0x55 => [:SSTORE, 2, 0, 0],
      0x56 => [:JUMP, 1, 0, 8],
      0x57 => [:JUMPI, 2, 0, 10],
      0x58 => [:PC, 0, 1, 2],
      0x59 => [:MSIZE, 0, 1, 2],
      0x5a => [:GAS, 0, 1, 2],
      0x5b => [:JUMPDEST, 0, 0, 1],
      0x5c => [:SLOADEXT, 2, 1, 50],
      0x5d => [:SSTOREEXT, 3, 0, 0],
      0x5e => [:SLOADEXTBYTES, 3, 0, 50],
      0x5f => [:SSTOREEXTBYTES, 2, 0, 2500],
      0xa0 => [:LOG0, 2, 0, 0],
      0xa1 => [:LOG1, 3, 0, 0],
      0xa2 => [:LOG2, 4, 0, 0],
      0xa3 => [:LOG3, 5, 0, 0],
      0xa4 => [:LOG4, 6, 0, 0],
      0xf0 => [:CREATE, 3, 1, 32000],
      0xf1 => [:CALL, 7, 1, 40],
      0xf2 => [:CALLCODE, 7, 1, 40],
      0xf3 => [:RETURN, 2, 0, 0],
      0xf4 => [:DELEGATECALL, 6, 1, 40],
      0xf5 => [:BREAKPOINT, 0, 0, 1],
      0xf6 => [:RNGSEED, 1, 1, 50],
      0xf7 => [:SSIZEEXT, 2, 1, 50],
      0xf8 => [:SLOADBYTES, 3, 0, 50],
      0xf9 => [:SSTOREBYTES, 2, 0, 2500],
      0xfa => [:SSIZE, 1, 1, 50],
      0xfb => [:STATEROOT, 1, 1, 50],
      0xfc => [:TXGAS, 0, 1, 50],
      0xfd => [:CALLSTATIC, 7, 1, 50],
      0xff => [:SUICIDE, 1, 0, 0],
    }

    PREFIX_LOG  = 'LOG'.freeze
    PREFIX_PUSH = 'PUSH'.freeze
    PREFIX_DUP  = 'DUP'.freeze
    PREFIX_SWAP = 'SWAP'.freeze

    32.times do |i|
      TABLE[0x60+i] = [:"#{PREFIX_PUSH}#{i+1}", 0, 1, 3]
    end

    16.times do |i|
      TABLE[0X80+i] = [:"#{PREFIX_DUP}#{i+1}", i+1, i+2, 3]
      TABLE[0x90+i] = [:"#{PREFIX_SWAP}#{i+1}", i+2, i+2, 3]
    end

    REVERSE_TABLE = {}
    TABLE.each do |code, defn|
      const_set defn[0], defn
      REVERSE_TABLE[defn[0]] = code
    end

    TABLE.freeze
    REVERSE_TABLE.freeze

    # Non-opcode gas prices
    GDEFAULT = 1
    GMEMORY = 3
    GQUADRATICMEMDENOM = 512  # 1 gas per 512 quadwords
    GSTORAGEREFUND = 15000
    GSTORAGEKILL = 5000
    GSTORAGEMOD = 5000
    GSTORAGEADD = 20000
    GEXPONENTBYTE = 10    # cost of EXP exponent per byte
    GCOPY = 3             # cost to copy one 32 byte word
    GCONTRACTBYTE = 200   # one byte of code in contract creation
    GCALLVALUETRANSFER = 9000   # non-zero-valued call
    GLOGBYTE = 8          # cost of a byte of logdata
    GLOGBASE = 375        # basic log
    GLOGTOPIC = 375       # log topic
    GCREATE = 32000       # contract creation base cost
    GGASDEPOSIT = 2000    # cost of using gas deposit process

    GTXCOST = 21000       # TX BASE GAS COST
    GTXDATAZERO = 4       # TX DATA ZERO BYTE GAS COST
    GTXDATANONZERO = 68   # TX DATA NON ZERO BYTE GAS COST
    GSHA3WORD = 6         # Cost of SHA3 per word
    GSHA256BASE = 60      # Base c of SHA256
    GSHA256WORD = 12      # Cost of SHA256 per word
    GRIPEMD160BASE = 600  # Base cost of RIPEMD160
    GRIPEMD160WORD = 120  # Cost of RIPEMD160 per word
    GIDENTITYBASE = 15    # Base cost of indentity
    GIDENTITYWORD = 3     # Cost of identity per word
    GECRECOVER = 3000     # Cost of ecrecover op
    GECADD = 200          # Cost of ecadd op
    GECMUL = 1000         # Cost of ecmul op
    GMODEXP = 200         # Cost of modexp op
    GRLPBASE = 30         # Base cost of RLP decoding
    GRLPWORD = 6          # Cost of RLP decoding per word

    GSTIPEND = 2300

    GCALLNEWACCOUNT = 25000
    GSUICIDEREFUND = 24000

  end
end
