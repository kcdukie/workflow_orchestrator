#
# == workflow_fsm.ex
#
# This module contains the gen_fsm for Workflow Orchestration.  Most executions 
# through this FSM will follow one of the following path(s):
#
#   * Workflow is complete
#     :workflow_starting
#     :workflow_completed
#   * Build
#     :workflow_starting
#     :build
#     :workflow_completed
#   * Deploy
#     :workflow_starting
#     :deploy
#     :workflow_completed
#
require Logger
require Timex.Date

defmodule OpenAperture.WorkflowOrchestrator.WorkflowFSM do

  @moduledoc """
  This module contains the gen_fsm for Workflow Orchestration
  """

  use Timex

  @behaviour :gen_fsm

  alias OpenAperture.WorkflowOrchestrator.Workflow
  alias OpenAperture.WorkflowOrchestrator.Configuration
  alias OpenAperture.WorkflowOrchestrator.Dispatcher
  alias OpenAperture.WorkflowOrchestrator.Builder.DockerHostResolver
  alias OpenAperture.WorkflowOrchestrator.Builder.Publisher, as: BuilderPublisher
  alias OpenAperture.WorkflowOrchestrator.Deployer.Publisher, as: DeployerPublisher
  alias OpenAperture.WorkflowOrchestrator.Deployer.EtcdClusterMessagingResolver

  @doc """
  Method to start a WorkflowFSM

  ## Options

  The `payload` options defines the payload of the Workflow

  The `delivery_tag` options defines the identifier of the request message to which this FSM is associated

  ## Return Values
  
  {:ok, WorkflowFSM} | {:error, reason}
  """
  @spec start_link(Map, String.t()) :: {:ok, pid} | {:error, String.t()}
	def start_link(payload, delivery_tag) do
    case Workflow.create_from_payload(payload) do
      {:error, reason} -> {:error, reason}
      workflow -> :gen_fsm.start_link(__MODULE__, %{workflow: workflow, delivery_tag: delivery_tag}, [])
    end
	end

  @doc """
  Method to execute a (rescursive) run of the WorkflowFSM

  ## Options

  The `workflowfsm` option defines the PID of the FSM

  ## Return Values
  
  :completed
  """
  @spec execute(pid) :: :completed
  def execute(workflowfsm) do
    case :gen_fsm.sync_send_event(workflowfsm, :execute_next_workflow_step) do
      :in_progress -> execute(workflowfsm)
      {result, workflow} -> {result, workflow}
    end
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:init-1

  ## Options

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:ok, :workflow_starting, state_data}
  """
  @spec init(pid) :: {:ok, :workflow_starting, Map}
	def init(state_data) do
    state_data = Map.put(state_data, :workflow_fsm_id, "#{UUID.uuid1()}")
    state_data = Map.put(state_data, :workflow_fsm_prefix, "[WorkflowFSM][#{state_data[:workflow_fsm_id]}][Workflow][#{Workflow.get_id(state_data[:workflow])}]")
    {:ok, :workflow_starting, state_data}
	end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:terminate-3

  ## Options

  The `reason` option defines the termination reason (:shutdown, :normal)

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  :ok
  """
  @spec terminate(term, term, Map) :: :ok
	def terminate(_reason, _current_state, state_data) do
		Logger.debug("#{state_data[:workflow_fsm_prefix]} Workflow Orchestration has finished normally")
		:ok
	end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:code_change-4

  ## Options

  The `old_vsn` option:  OldVsn = Vsn | {down, Vsn}

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  The `opts` option contains additional extra options

  ## Return Values
  
  {:ok, term, Map}
  """
  @spec code_change(term, term, Map, term) :: {:ok, term, Map}
  def code_change(_old_vsn, current_state, state_data, _opts) do
    {:ok, current_state, state_data}
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_info-3

  ## Options

  The `info` option contains additional extra options

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:next_state,term,Map}
  """
  @spec handle_info(term, term, Map) :: {:next_state,term,Map}
  def handle_info(_info, current_state, state_data) do
    {:next_state,current_state,state_data}
  end    

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_event-3

  ## Options

  The `event` option contains the current event received by the server

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:next_state,term,Map}
  """
  @spec handle_event(term, term, Map) :: {:next_state,term,Map}
  def handle_event(_event, current_state, state_data) do
    {:next_state,current_state,state_data}
  end   

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_sync_event-4

  ## Options

  The `event` option contains the current event received by the server

  The `from` option contains the caller of the server

  The `current_state` option contains the last state of the :gen_fsm server

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:next_state,term,Map}
  """
  @spec handle_sync_event(term, term, term, Map) :: {:next_state,term,Map}
  def handle_sync_event(_event, _from, current_state, state_data) do
    {:next_state,current_state,state_data}
  end 

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-3 for the state :workflow_starting
  This callback will take the following action(s):
    * Save the current Workflow
    * If workflow is not completed, transition to the next workflow state
    * If workflow is completed, transition to :workflow_completed

  ## Options

  The `current_state` option contains the last state of the :gen_fsm server

  The `from` option contains the caller of the state transition

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:reply, :in_progress, next_milestone, state_data}
  """
  @spec workflow_starting(term, term, Map) :: {:reply, :in_progress, term, Map}
  def workflow_starting(_current_state, _from, state_data) do
    Logger.debug("#{state_data[:workflow_fsm_prefix]} Starting Workflow Orchestration for request message #{state_data[:delivery_tag]}...")

    Logger.debug("#{state_data[:workflow_fsm_prefix]} Saving workflow...")
    Workflow.save(state_data[:workflow])

    case Workflow.complete?(state_data[:workflow]) do
      true -> 
        Logger.debug("#{state_data[:workflow_fsm_prefix]} Workflow is complete")
        {:reply, :in_progress, :workflow_completed, state_data}
      false -> {:reply, :in_progress, Workflow.resolve_next_milestone(state_data[:workflow]), state_data}
    end
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-3 for the state :workflow_completed
  This callback will take the following action(s):
    * Stop the :gen_fsm

  ## Options

  The `current_state` option contains the last state of the :gen_fsm server

  The `from` option contains the caller of the state transition

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:stop, :normal, {:completed, state_data[:workflow]}, state_data}
  """
  @spec workflow_completed(term, term, Map) :: {:stop, :normal, {:completed, pid}, Map}
  def workflow_completed(_current_state, _from, state_data) do
    Logger.debug("#{state_data[:workflow_fsm_prefix]} Finishing Workflow Orchestration...")
    {:stop, :normal, {:completed, state_data[:workflow]}, state_data}
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-3 for the state :build
  This callback will take the following action(s):
    * Resolve a messaging_exchange to send a Builder message
      * Fail the workflow if the resolution fails
    * Publish a Builder request
    * Transition to :workflow_completed

  ## Options

  The `current_state` option contains the last state of the :gen_fsm server

  The `from` option contains the caller of the state transition

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:reply, :in_progress, :workflow_completed, state_data}
  """
  @spec build(term, term, Map) :: {:reply, :in_progress, :workflow_completed, Map}
  def build(_event, _from, state_data) do  
    Logger.debug("#{state_data[:workflow_fsm_prefix]} Requesting build...")   
    {messaging_exchange_id, docker_build_etcd_cluster} = DockerHostResolver.next_available
    if docker_build_etcd_cluster == nil do
      Workflow.workflow_failed(state_data[:workflow], "Unable to request build - no build clusters are available!")
      Dispatcher.acknowledge(state_data[:delivery_tag])
    else
      payload = Workflow.get_info(state_data[:workflow])
      payload = Map.put(payload, :docker_build_etcd_token, docker_build_etcd_cluster["etcd_token"])

      #default entries for all communications to children
      payload = Map.put(payload, :notifications_exchange_id, Configuration.get_current_exchange_id)
      payload = Map.put(payload, :notifications_broker_id, Configuration.get_current_broker_id)
      payload = Map.put(payload, :orchestration_exchange_id, Configuration.get_current_exchange_id)
      payload = Map.put(payload, :orchestration_broker_id, Configuration.get_current_broker_id)
      payload = Map.put(payload, :orchestration_queue_name, "workflow_orchestration")

      Logger.debug("#{state_data[:workflow_fsm_prefix]} Saving workflow...")
      Workflow.save(state_data[:workflow])

      BuilderPublisher.build(state_data[:delivery_tag], messaging_exchange_id, payload)
    end

    # after this action, we want to complete the current Workflow Orchestration.  The worker will
    # call back in after it's action has been completed
    {:reply, :in_progress, :workflow_completed, state_data}
  end

  @doc """
  :gen_fsm callback - http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-3 for the state :deploy
  This callback will take the following action(s):
    * Resolve a messaging_exchange to send a Deployer message
      * Fail the workflow if the resolution fails
    * Publish a Deployer request
    * Transition to :workflow_completed

  ## Options

  The `current_state` option contains the last state of the :gen_fsm server

  The `from` option contains the caller of the state transition

  The `state_data` option contains the default state data of the :gen_fsm server

  ## Return Values
  
  {:reply, :in_progress, :workflow_completed, state_data}
  """
  @spec deploy(term, term, Map) :: {:reply, :in_progress, :workflow_completed, Map}
  def deploy(_event, _from, state_data) do  
    Logger.debug("#{state_data[:workflow_fsm_prefix]} Requesting deploy...")

    workflow_info = Workflow.get_info(state_data[:workflow])
    messaging_exchange_id = EtcdClusterMessagingResolver.exchange_for_cluster(workflow_info[:etcd_token])
    if messaging_exchange_id == nil do
      Workflow.workflow_failed(state_data[:workflow], "Unable to request deploy to cluster #{workflow_info[:etcd_token]} - cluster is not associated with an exchange!")
      Dispatcher.acknowledge(state_data[:delivery_tag])
    else
      #default entries for all communications to children
      workflow_info = Workflow.get_info(state_data[:workflow])
      payload = workflow_info
      payload = Map.put(payload, :notifications_exchange_id, Configuration.get_current_exchange_id)
      payload = Map.put(payload, :notifications_broker_id, Configuration.get_current_broker_id)
      payload = Map.put(payload, :orchestration_exchange_id, Configuration.get_current_exchange_id)
      payload = Map.put(payload, :orchestration_broker_id, Configuration.get_current_broker_id)      
      payload = Map.put(payload, :orchestration_queue_name, "workflow_orchestration")

      Logger.debug("#{state_data[:workflow_fsm_prefix]} Saving workflow...")
      Workflow.save(state_data[:workflow])

      DeployerPublisher.deploy(state_data[:delivery_tag], messaging_exchange_id, payload)       
    end

    # after this action, we want to complete the current Workflow Orchestration.  The worker will
    # call back in after it's action has been completed
    {:reply, :in_progress, :workflow_completed, state_data}
  end
end