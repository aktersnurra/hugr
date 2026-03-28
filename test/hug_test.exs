defmodule HugTest do
  use ExUnit.Case

  test "agent starts and is registered" do
    assert Process.whereis(Hug.Agent) != nil
  end
end
