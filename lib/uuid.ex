defmodule UUID do
	use Bitwise, only_operators: true
  @moduledoc """
  UUID generator and utilities for Elixir.
  See [RFC 4122](http://www.ietf.org/rfc/rfc4122.txt).
  """

  # Offset between 15 October 1582 and 1 January 1970.
  @nanosec_intervals_offset 122192928000000000
  # Microseconds to nanoseconds factor.
  @nanosec_intervals_factor 10

  # Variant, corresponds to variant 1 0 of RFC 4122.
  @variant10 2
  # UUID v1 identifier.
  @uuid_v1 1
  # UUID v3 identifier.
  @uuid_v3 3
  # UUID v4 identifier.
	@uuid_v4 4
	# UUID v5 identifier.
	@uuid_v5 5

	@urn "urn:uuid:"

  @doc """
	Inspect a UUID and return information about its type, version and variant.

	Timestamp portion is not checked

  ## Examples

    iex> UUID.info("4995555a-1361-4b45-5803-9ef16250956c")
    [uuid: "4995555a-1361-4b45-5803-9ef16250956c",
     type: :default,
     version: 4,
     variant: :rfc4122]

		iex> UUID.info("da55ad7a21334017445da3e25682e4e8")
    [uuid: "da55ad7a21334017445da3e25682e4e8",
     type: :hex,
     version: 4,
     variant: :rfc4122]

    iex> UUID.info("urn:uuid:968dd402-edc8-11e3-568c-14109ff1a304")
    [uuid: "urn:uuid:968dd402-edc8-11e3-568c-14109ff1a304",
     type: :urn,
     version: 1,
     variant: :rfc4122]

  """
  def info(<<uuid::binary>> = original) do
  	uuid = String.downcase(uuid)
  	{type, uuid} = case uuid do
      <<u0::64, "-", u1::32, "-", u2::32, "-", u3::32, "-", u4::96>> ->
      	{:default, <<u0::64, u1::32, u2::32, u3::32, u4::96>>}
      <<u0::256>> ->
        {:hex, <<u0::256>>}
      <<@urn, u0::64, "-", u1::32, "-", u2::32, "-", u3::32, "-", u4::96>> ->
      	{:urn, <<u0::64, u1::32, u2::32, u3::32, u4::96>>}
      _ ->
      	raise ArgumentError, message: "Not a valid UUID"
  	end
  	{:ok, [uuid], []} = :io_lib.fread('~16u', to_char_list(uuid))
  	uuid = <<uuid::128>>
    <<_::48, version::4, _::12, v0::1, v1::1, v2::1, _::61>> = uuid
    [uuid: original,
     type: type,
     version: version,
     variant: variant(<<v0, v1, v2>>)]
  end
  def info(_) do
    raise ArgumentError, message: "Expected: String"
  end

  @doc """
  Generate a new UUID v1. This version uses a combination of one or more of:
  unix epoch, random bytes, pid hash, and hardware address.

  ## Examples

    iex> UUID.uuid1()
    "2fd5fcba-ed70-11e3-b7e3-1f299fdda3d4"

    iex> UUID.uuid1(:default)
    "2fd5fcba-ed70-11e3-b7e3-1f299fdda3d4"

    iex> UUID.uuid1(:hex)
    "2fd5fcbaed7011e3b7e31f299fdda3d4"

    iex> UUID.uuid1(:urn)
    "urn:uuid:2fd5fcba-ed70-11e3-b7e3-1f299fdda3d4"

  """
	def uuid1(format \\ :default) do
		<<time_hi::12, time_mid::16, time_low::32>> = uuid1_time()
    <<clock_seq_hi::6, clock_seq_low::8>> = uuid1_clockseq()
    <<node::48>> = uuid1_node()
    <<time_low::32, time_mid::16, @uuid_v1::4, time_hi::12, @variant10::2,
      clock_seq_hi::6, clock_seq_low::8, node::48>>
      |> uuid_to_string format
	end

  @doc """
  Generate a new UUID v3. This version uses an MD5 hash of fixed value (chosen
  based on a namespace atom - see Appendix C of RFC 4122) and a name value.

  Accepted arguments are: :dns|:url|:oid|:x500|:nil, String

  ## Examples

    iex> UUID.uuid3(:dns, "name")
    "47f5e2c5-e9b3-3d11-ba7c-25ef963a1a6e"

    iex> UUID.uuid3(:dns, "name", :default)
    "47f5e2c5-e9b3-3d11-ba7c-25ef963a1a6e"

    iex> UUID.uuid3(:dns, "name", :hex)
    "47f5e2c5e9b33d11ba7c25ef963a1a6e"

    iex> UUID.uuid3(:dns, "name", :urn)
    "urn:uuid:47f5e2c5-e9b3-3d11-ba7c-25ef963a1a6e"

  """
	def uuid3(:dns, <<name::binary>>, format \\ :default) do
    namebased_uuid(:md5, <<"6ba7b8109dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid3(:url, <<name::binary>>, format) do
    namebased_uuid(:md5, <<"6ba7b8119dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid3(:oid, <<name::binary>>, format) do
    namebased_uuid(:md5, <<"6ba7b8129dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid3(:x500, <<name::binary>>, format) do
    namebased_uuid(:md5, <<"6ba7b8149dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid3(:nil, <<name::binary>>, format) do
  	namebased_uuid(:md5, <<0::128, name::binary>>)
  	  |> uuid_to_string format
  end
  def uuid3(_, _, _) do
    raise ArgumentError, message: "Expected: :dns|:url|:oid|:x500|:nil, String"
  end

  @doc """
  Generate a new UUID v4. This version uses pseudo-random bytes generated by
  the `crypto` module.

  ## Examples

    iex> UUID.uuid4()
    "3c69679f-774b-4fb1-80c1-7b29c6e7d0a0"

    iex> UUID.uuid4(:default)
    "3c69679f-774b-4fb1-80c1-7b29c6e7d0a0"

    iex> UUID.uuid4(:hex)
    "3c69679f774b4fb180c17b29c6e7d0a0"

    iex> UUID.uuid4(:urn)
    "urn:uuid:3c69679f-774b-4fb1-80c1-7b29c6e7d0a0"

  """
	def uuid4(format \\ :default) do
		<<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.rand_bytes(16)
		<<u0::48, @uuid_v4::4, u1::12, @variant10::2, u2::62>>
      |> uuid_to_string format
	end

  @doc """
  Generate a new UUID v5. This version uses an SHA1 hash of fixed value (chosen
  based on a namespace atom - see Appendix C of RFC 4122) and a name value.

  Accepted arguments are: :dns|:url|:oid|:x500|:nil, String

  ## Examples

    iex> UUID.uuid5(:dns, "name")
    "40079f8e-7923-5c5c-8ee1-fee2257890e5"

    iex> UUID.uuid5(:dns, "name", :default)
    "40079f8e-7923-5c5c-8ee1-fee2257890e5"

    iex> UUID.uuid5(:dns, "name", :hex)
    "40079f8e79235c5c8ee1fee2257890e5"

    iex> UUID.uuid5(:dns, "name", :urn)
    "urn:uuid:40079f8e-7923-5c5c-8ee1-fee2257890e5"

  """
	def uuid5(:dns, <<name::binary>>, format \\ :default) do
    namebased_uuid(:sha1, <<"6ba7b8109dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid5(:url, <<name::binary>>, format) do
    namebased_uuid(:sha1, <<"6ba7b8119dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid5(:oid, <<name::binary>>, format) do
    namebased_uuid(:sha1, <<"6ba7b8129dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid5(:x500, <<name::binary>>, format) do
    namebased_uuid(:sha1, <<"6ba7b8149dad11d180b400c04fd430c8", name::binary>>)
      |> uuid_to_string format
  end
  def uuid5(:nil, <<name::binary>>, format) do
    namebased_uuid(:sha1, <<0::128, name::binary>>)
      |> uuid_to_string format
  end
  def uuid5(_, _, _) do
    raise ArgumentError, message: "Expected: :dns|:url|:oid|:x500|:nil, String"
  end

  # String formatting function.
	defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>, :default) do
		:io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
			             [u0, u1, u2, u3, u4])
		  |> to_string
	end
	defp uuid_to_string(<<u::128>>, :hex) do
		:io_lib.format("~32.16.0b", [u])
		  |> to_string
	end
	defp uuid_to_string(u, :urn) do
		@urn <> uuid_to_string(u, :default)
	end
	defp uuid_to_string(_u, format) do
    raise ArgumentError, message: "Invalid format " <> to_string(format) <>
                                  "; Expected: :default|:hex|:urn"
	end

  #
  # Internal utility functions.
  #

  # Get unix epoch as a 60-bit timestamp.
	defp uuid1_time() do
		{mega_sec, sec, micro_sec} = :erlang.now()
    epoch = (mega_sec * 1000000000000 + sec * 1000000 + micro_sec)
    timestamp = @nanosec_intervals_offset + @nanosec_intervals_factor * epoch
		<<timestamp::60>>
	end

  # Generate random clock sequence.
	defp uuid1_clockseq() do
		pid_sum = :erlang.phash2(:erlang.self())
    <<n0::32, n1::32, n2::32>> = :crypto.rand_bytes(12)
    now_xor_pid = {n0 ^^^ pid_sum, n1 ^^^ pid_sum, n2 ^^^ pid_sum}
    :random.seed(now_xor_pid)
    rnd = :random.uniform(2 <<< 14 - 1)
    <<rnd::14>>
	end

  # Get local IEEE 802 (MAC) address, or a random node id if it can't be found.
  defp uuid1_node() do
    {:ok, ifs0} = :inet.getifaddrs()
    uuid1_node(ifs0)
  end

  # Skip loopback adapter.
  defp uuid1_node([{"lo", _if_config} | rest]) do
    uuid1_node(rest)
  end
  defp uuid1_node([{_if_name, if_config} | rest]) do
    case :lists.keyfind(:hwaddr, 1, if_config) do
      {:hwaddr, hw_addr} ->
        :erlang.list_to_binary(hw_addr)
      :false ->
        uuid1_node(rest)
    end
  end
  defp uuid1_node(_) do
    <<rnd_hi::7, _::1, rnd_low::40>> = :crypto.rand_bytes(6)
    <<rnd_hi::7, 1::1, rnd_low::40>>
  end

  # Generate a hash of the given data.
  defp namebased_uuid(:md5, data) do
    md5 = :crypto.hash(:md5, data)
    compose_namebased_uuid(@uuid_v3, md5)
  end
  defp namebased_uuid(:sha1, data) do
    <<sha1::128, _::32>> = :crypto.hash(:sha, data)
    compose_namebased_uuid(@uuid_v5, <<sha1::128>>)
  end

  # Format the given hash as a UUID.
  defp compose_namebased_uuid(version, hash) do
    <<time_low::32, time_mid::16, _::4, time_hi::12, _::2,
      clock_seq_hi::6, clock_seq_low::8, node::48>> = hash
    <<time_low::32, time_mid::16, version::4, time_hi::12, @variant10::2,
      clock_seq_hi::6, clock_seq_low::8, node::48>>
  end

  # Identify the UUID variant according to section 4.1.1 of RFC 4122.
  defp variant(<<1, 1, 1>>) do
    :reserved_future
  end
  defp variant(<<1, 1, _v>>) do
    :reserved_microsoft
  end
  defp variant(<<1, 0, _v>>) do
    :rfc4122
  end
  defp variant(<<0, _v::[2, binary]>>) do
    :reserved_ncs
  end
  defp variant(_) do
    :unknown
  end

end