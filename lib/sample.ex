defmodule SampleProducer do
  def start(id, q) do
    IO.puts("PRODUCER #{id} STARTO")
    spawn(fn -> loop(id, q) end)
  end

  defp loop(id, q) do
    :random.seed(System.os_time())
    job = :random.uniform(10) * 100
    IO.puts("\t\t\t\t\tPRODUCER #{id}: Generating job #{job}")
    Process.sleep(job)

    IO.puts("\t\t\t\t\tPRODUCER #{id}: Sending job #{job} to the queue")
    # send(q, {:producer, job, id})

    loop(id, q)
  end
end

defmodule SampleConsumer do
  def start(id, q) do
    IO.puts("CONSUMER #{id} STARTO")
    spawn(fn -> loop(id, q) end)
  end

  defp loop(id, q) do
    IO.puts("\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Ready")

    send(q, {:consumer, id, self()})

    receive do
      {:job, job, producer_id} ->
        IO.puts("\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Received job #{job} from #{producer_id}")
        Process.sleep(job)
        loop(id, q)
    end
  end
end

defmodule SampleQueue do
  def start(producers \\ 5, consumers \\ 5, size \\ 2) do
    for id <- 1..producers, do: SampleProducer.start(id, self())
    # for id <- 1..consumers, do: SampleConsumer.start(id, self())
    loop([], [], size)
  end

  defp loop(jobs, consumers, size) do
    receive do
      {:consumer, consumer_id, consumer_pid} = consumer ->
        IO.puts("Q #{stats(jobs, consumers)}: Consumer #{consumer_id} ready")

        consume_job(jobs, [consumer | consumers], size)

      {:producer, job, producer_id} ->
        process_job({:job, job, producer_id}, jobs, consumers, size)
    end
  end

  defp consume_job(jobs, consumers, size) when jobs == [] do
    loop(jobs, consumers, size)
  end

  defp consume_job([job | jobs], consumers, size) do
    process_job(job, jobs, consumers, size)
  end

  defp process_job({:job, job, producer_id}, jobs, consumers, size)
       when length(jobs) >= size and consumers == [] do
    IO.puts(
      "Q #{stats(jobs, consumers)}: Full. Discarding job #{job} from PRODUCER #{producer_id}"
    )

    loop(jobs, consumers, size)
  end

  defp process_job({:job, job, producer_id} = new_job, jobs, consumers, size)
       when consumers == [] do
    jobs = [new_job | jobs]
    IO.puts("Q #{stats(jobs, consumers)}: Queueing job #{job} from PRODUCER #{producer_id}")
    loop(jobs, consumers, size)
  end

  defp process_job({:job, job, producer_id} = new_job, jobs, consumers, size) do
    [{:consumer, consumer_id, consumer_pid} | consumers] = consumers

    IO.puts(
      "Q #{stats(jobs, consumers)}: Sending job #{job} from PRODUCER #{producer_id} to CONSUMER #{
        consumer_id
      }"
    )

    send(consumer_pid, new_job)
    loop(jobs, consumers, size)
  end

  defp stats(job, consumers) do
    inspect({length(job), length(consumers)})
  end
end
