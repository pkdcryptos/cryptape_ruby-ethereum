# -*- encoding : ascii-8bit -*-

require 'test_helper'

class VMFixtureTest < Minitest::Test
  include Ethereum

  # TODO: FIXME:
  # these cases failed due to ruby array's limitation:
  #
  #   [][2**63-1] => nil
  #   [][2**63] => RangeError: bignum too big to convert into 'long'
  #
  PendingTests = %w(
    vmInputLimitsLight_0911f8a8e163b17b94315c49507925171ff506f25460e3b584f3fe6dcfa172e2
    vmInputLimitsLight_0322751b60db071ea7c6885f6f3eaf0b83af83856ba5a72e3a87404cc171fac3
    vmInputLimitsLight_00dfb8715c277e8af73a2ce9f1bf7e63676d851f46eb48b22363fdeebd1af698
    vmInputLimitsLight_0ccf8d831e1047220965c239edbd1d728b588fe576e670fe552566d1ac01e301
    vmInputLimitsLight_0b594a8c01b32c4f0ef320bffc697b3b50d58e6eefc632771c7e194c61f1a313
    vmInputLimitsLight_10faa232a46728443dc5efbfe7cf5d6c55effd9e624f2f585113160ee9ad0ddf
    vmInputLimitsLight_12d6dfb1325788b738e1763c90b6a193948705ef04a99fa22fd3f0a9ac957b92
    vmInputLimitsLight_197ea8171aa28072831191525572242dca3de187925082cd486b13ffb12ea38f
    vmInputLimitsLight_1b0e78dfcd88f622cab1893a484215254b2e1a8aeec08a7c9be6425a579dc80d
    vmInputLimitsLight_3461e9666cac332c92a6e85cc0ca338938e553a2499948ac12436365932232e2
    vmInputLimitsLight_2bda7c037e72ae25525c6ea38ad34e2819d1c5ce20404528842c251e4cce6d0f
  )

  set_fixture_limit 2048
  run_fixture "VMTests/vmArithmeticTest.json"
  #run_fixtures "VMTests"

  @@env = Env.new DB::EphemDB.new

  def on_fixture_test(name, data)
    if PendingTests.include?(name)
      skip("pending")
    end

    check_vm_test data
  end

  def check_vm_test(params)
    run_vm_test params, :verify
  end

  # @param mode [Symbol] :fill, :verify or :time
  def run_vm_test(params, mode, profiler=nil)
    pre = params['pre']
    exec = params['exec']
    env = params['env']

    env['previousHash'] = encode_hex(@@env.config[:genesis_prevhash]) unless env.has_key?('previousHash')
    assert_equal %w(currentCoinbase currentDifficulty currentGasLimit currentNumber currentTimestamp previousHash).sort, env.keys.sort

    # setup env
    header = BlockHeader.new(
      prevhash: decode_hex(env['previousHash']),
      number: parse_int_or_hex(env['currentNumber']),
      coinbase: decode_hex(env['currentCoinbase']),
      difficulty: parse_int_or_hex(env['currentDifficulty']),
      gas_limit: parse_int_or_hex(env['currentGasLimit']),
      timestamp: parse_int_or_hex(env['currentTimestamp'])
    )
    blk = Block.new header, env: @@env

    # setup pre allocations
    pre.each do |address, h|
      assert_equal 40, address.size
      assert_equal %w(balance code nonce storage), h.keys.sort

      address = decode_hex address

      blk.set_nonce address, parse_int_or_hex(h['nonce'])
      blk.set_balance address, parse_int_or_hex(h['balance'])
      blk.set_code address, decode_hex(h['code'][2..-1])

      h['storage'].each do |k, v|
        blk.set_storage_data(
          address,
          Utils.big_endian_to_int(decode_hex(k[2..-1])),
          Utils.big_endian_to_int(decode_hex(v[2..-1]))
        )
      end
    end

    # execute transactions
    sender = decode_hex exec['caller']
    to = decode_hex exec['address']
    nonce = blk.get_nonce sender
    gasprice = parse_int_or_hex exec['gasPrice']
    startgas = parse_int_or_hex exec['gas']
    value = parse_int_or_hex exec['value']
    data = decode_hex exec['data'][2..-1]

    # bypass gas check in tx initialization by temporarily increasing startgas
    num_zero_bytes = data.count(Constant::BYTE_ZERO)
    num_non_zero_bytes = data.size - num_zero_bytes
    intrinsic_gas = Opcodes::GTXCOST +
      Opcodes::GTXDATAZERO*num_zero_bytes +
      Opcodes::GTXDATANONZERO*num_non_zero_bytes

    startgas += intrinsic_gas
    tx = Transaction.new nonce: nonce, gasprice: gasprice, startgas: startgas, to: to, value: value, data: data
    tx.startgas -= intrinsic_gas
    tx.sender = sender

    # capture apply_message calls
    apply_message_calls = []

    ext = get_ext_wrapper ExternalCall.new(blk, tx), apply_message_calls

    cd = VM::CallData.new(Utils.bytes_to_int_array(tx.data))
    msg = VM::Message.new tx.sender, tx.to, tx.value, tx.startgas, cd
    code = decode_hex exec['code'][2..-1]

    t1 = Time.now
    #profiler.enable if profiler # TODO
    success, gas_remained, output = VM.execute(ext, msg, code)
    #profiler.disable if profiler

    blk.commit_state
    blk.suicides.each {|s| blk.del_account(s) }
    t2 = Time.now

    # Generally expected that the test implementer will read env, exec and pre
    # then check their results against gas, logs, out, post and callcreates.
    #
    # If an exception is expected, then latter sections are absent in the test.
    # Since the reverting of the state is not part of the VM tests.

    params2 = Marshal.load Marshal.dump(params) # poorman's deep copy

    if success != 0
      params2['callcreates'] = apply_message_calls
      params2['out'] = "0x#{encode_hex Utils.int_array_to_bytes(output)}"
      params2['gas'] = gas_remained.to_s
      params2['logs'] = blk.logs.map {|l| l.to_h }
      params2['post'] = blk.to_h(with_state: true)[:state]
    end

    case mode
    when :fill
      params2
    when :verify
      assert !params.has_key?('post'), 'failed, but expected to succeed' unless success

      params1 = Marshal.load Marshal.dump(params) # poorman's deep copy
      shouldbe, reallyis = params1['post'], params2['post']
      compare_post_states shouldbe, reallyis

      %w(pre exec env callcreates out gas logs).each do |k|
        shouldbe = normalize_value k, params1
        reallyis = normalize_value k, params2
        raise "Mismatch: #{k}\n shouldbe: #{shouldbe} reallyis: #{reallyis}" if shouldbe != reallyis
      end
    when :time
      t2 - t1
    end
  end

  def get_ext_wrapper(ext, apply_message_calls)
    class <<ext
      attr_accessor :apply_message_calls

      alias :orig_msg :msg
      alias :orig_create :create
      alias :orig_block_hash :block_hash

      def msg(msg)
        hexdata = encode_hex msg.data.extract_all

        apply_message_calls.push(
          gasLimit: msg.gas,
          value: msg.value,
          to: encode_hex(msg.to),
          data: "0x#{hexdata}"
        )

        [1, msg.gas, Ethereum::Constant::BYTE_EMPTY]
      end

      def create(msg)
        sender = msg.sender.size == 40 ? decode_hex(msg.sender) : msg.sender
        nonce = Ethereum::Utils.encode_int @block.get_nonce(msg.sender)
        addr = Ethereum::Utils.keccak256_rlp([sender, nonce])[12..-1]
        hexdata = encode_hex msg.data.extract_all

        apply_message_calls.push(
          gasLimit: msg.gas,
          value: msg.value,
          to: Ethereum::Constant::BYTE_EMPTY,
          data: "0x#{hexdata}"
        )

        [1, msg.gas, addr]
      end

      def block_hash(n)
        if n >= block_number || n < block_number-256
          Ethereum::Constant::BYTE_EMPTY
        else
          Ethereum::Utils.keccak256 n.to_s
        end
      end
    end

    ext.apply_message_calls = apply_message_calls

    ext
  end

  def compare_post_states(shouldbe, reallyis)
    return true if shouldbe.nil? && reallyis.nil?

    raise "state mismatch! shouldbe: #{shouldbe} reallyis: #{reallyis}" if shouldbe.nil? || reallyis.nil?

    shouldbe.each do |k, v|
      if !reallyis.has_key?(k)
        r = {nonce: 0, balance: 0, code: '0x', storage: {}}
      else
        r = acct_standard_form reallyis[k]
      end
      s = acct_standard_form shouldbe[k]

      raise "key #{k} state mismatch! shouldbe: #{s} reallyis: #{r}" if s != r
    end

    true
  end

  def acct_standard_form(a)
    a = symbolize_keys a

    storage = a[:storage]
      .map {|k,v| [normalize_hex(k), normalize_hex(v)] }
      .select {|(k,v)| v !~ /^0x0*$/ }
      .to_h

    { balance: parse_int_or_hex(a[:balance]),
      nonce: parse_int_or_hex(a[:nonce]),
      code: a[:code],
      storage: storage }
  end

  def normalize_hex(s)
    s.size > 2 ? s : '0x00'
  end

  def normalize_value(k, p)
    if p.has_key?(k)
      if k == :gas
        parse_int_or_hex(p[k])
      elsif k == :callcreates
        p[k].map {|c| callcreate_standard_form c }
      else
        k.to_s
      end
    end

    return nil
  end

  def symbolize_keys(h)
    h.map {|k,v| [k.to_sym, v] }.to_h
  end

end
