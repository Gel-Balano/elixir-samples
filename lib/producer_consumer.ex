defmodule Producer do
  use GenServer

  def start(id, p_pid) do
    GenServer.start(__MODULE__, %{id: id, p_pid: p_pid})
  end

  def init(state) do
    create_jobs(state)
    {:ok, state}
  end

  def create_jobs(%{id: id, p_pid: p_pid} = state) do
    :random.seed(System.os_time)
    job = :random.uniform(10) * 100
    IO.puts "\t\t\t\t\tPRODUCER #{id}: Generating job #{job}"
    Process.sleep(job)
    IO.puts "\t\t\t\t\tPRODUCER #{id}: Sending job #{job} to the queue"
    GenServer.cast(p_pid, {:producer, job, id})
    Process.send_after(self(), :loop_create, 100)
  end

  def handle_info(:loop_create, state) do
    create_jobs(state)
    {:noreply, state}
  end
end

defmodule Consumer do
  use GenServer

  def start(id, c_pid) do
    IO.puts "CONSUMER #{id} STARTO"
    GenServer.start(__MODULE__, %{id: id, c_pid: c_pid})
  end

  def init(state) do
    start_consumer(state)
    {:ok, state}
  end

  def start_consumer(%{id: id, c_pid: c_pid} = state) do
    IO.puts "\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Ready"
    GenServer.cast(c_pid, {:consumer, id, self()})
  end

  def handle_cast({:job, job, producer_id}, %{id: id} = state) do
    IO.puts "\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Received job #{job} from #{producer_id}"
    Process.sleep(job)
    start_consumer(state)
    {:noreply, state}
  end
end

defmodule Queue do
  use GenServer

  def start(producers \\ 5, consumers \\ 5, size \\ 5) do
    GenServer.start(__MODULE__, %{producers: producers, consumers: consumers, size: size})
  end

  def init(%{producers: producers, consumers: consumers, size: size}) do
    IO.puts "THE PRODS #{producers}"
    for id <- 1..producers, do: Producer.start(id, self())
    for id <- 1..consumers, do: Consumer.start(id, self())
    {:ok, %{jobs: [], consumers: [], buffer: size}}
  end

  def handle_cast({:consumer, consumer_id, consumer_pid} = consumer, %{jobs: jobs, consumers: consumers, buffer: size}) do
    IO.puts "Stats #{stats(jobs, consumers)}: Consumer #{consumer_id} ready"
    consume_job(jobs, [consumer | consumers], size)
  end

  def handle_cast({:producer, job, producer_id} = producer, %{jobs: jobs, consumers: consumers, buffer: size} = state) do
    IO.puts "Stats #{stats(jobs, consumers)}: Process #{job}"
    process_job({:job, job, producer_id}, jobs, consumers, size)
  end

  defp consume_job(jobs, consumers, size) when jobs == [] do
    {:noreply,  %{jobs: jobs, consumers: consumers, buffer: size}}
  end

  defp consume_job([job | jobs], consumers, size) do
    process_job(job, jobs, consumers, size)
  end

  defp process_job({:job, job, producer_id} = new_job, jobs, consumers, size) when length(jobs) >= size and consumers == [] do
    IO.puts "Stats #{stats(jobs, consumers)}: Full. Discarding job #{job} from PRODUCER #{producer_id}"
    {:noreply, %{jobs: jobs, consumers: consumers, buffer: size}}
  end

  defp process_job({:job, job, producer_id} = new_job, jobs, consumers, size) when consumers == [] do
    jobs = [new_job | jobs]
    IO.puts "Stats #{stats(jobs, consumers)}: Queueing job #{job} from PRODUCER #{producer_id}"
    {:noreply, %{jobs: jobs, consumers: consumers, buffer: size}}
  end

  defp process_job({:job, job, producer_id} = new_job, jobs, consumers, size) do
    [{:consumer, consumer_id, consumer_pid} | consumers] = consumers
    IO.puts "Stats #{stats(jobs, consumers)}: Sending job #{job} from PRODUCER #{producer_id} to CONSUMER #{consumer_id}"

    GenServer.cast(consumer_pid, new_job)
    {:noreply, %{jobs: jobs, consumers: consumers, buffer: size}}
  end

  defp stats(job, consumers) do
    inspect {length(job), length(consumers)}
  end
end
