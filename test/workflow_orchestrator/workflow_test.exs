defmodule OpenAperture.WorkflowOrchestrator.WorkflowTest do
  use ExUnit.Case

  alias OpenAperture.WorkflowOrchestrator.Workflow

  alias OpenAperture.WorkflowOrchestrator.Notifications.Publisher, as: NotificationsPublisher
  alias OpenAperture.ManagerApi.Workflow, as: WorkflowAPI
  alias OpenAperture.ManagerApi.Response

  # ============================
  # create_from_payload tests

  test "create_from_payload - create from scratch" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :create_workflow!, fn _, _ -> 123 end)
  	
  	payload = %{
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],

  	}

    workflow = Workflow.create_from_payload(payload)
    assert workflow != nil

    workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:workflow_start_time] != nil
    assert workflow_info[:workflow_completed] == false
    assert workflow_info[:workflow_error] == false
    assert workflow_info[:event_log] == []

    assert workflow_info[:id] == 123
    assert workflow_info[:workflow_id] == 123
    assert workflow_info[:deployment_repo] == payload[:deployment_repo]
    assert workflow_info[:deployment_repo_git_ref] == payload[:deployment_repo_git_ref]
    assert workflow_info[:source_repo] == payload[:source_repo]
    assert workflow_info[:source_repo_git_ref] == payload[:source_repo_git_ref]
    assert workflow_info[:source_commit_hash] == payload[:source_commit_hash]
    assert workflow_info[:milestones] == payload[:milestones]
  after
  	:meck.unload(WorkflowAPI)   
  end

  test "create_from_payload - create from scratch failed" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :create_workflow!, fn _, _ -> nil end)
  	
  	payload = %{
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],

  	}

    {result, reason} = Workflow.create_from_payload(payload)
    assert result == :error
    assert reason == "Failed to create a new Workflow with the ManagerApi!"
  after
  	:meck.unload(WorkflowAPI)   
  end

  test "create_from_payload - existing" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert workflow != nil

    workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:workflow_start_time] != nil
    assert workflow_info[:workflow_completed] == false
    assert workflow_info[:workflow_error] == false
    assert workflow_info[:event_log] == []

    assert workflow_info[:id] == payload[:id]
    assert workflow_info[:workflow_id] == payload[:workflow_id]
    assert workflow_info[:deployment_repo] == payload[:deployment_repo]
    assert workflow_info[:deployment_repo_git_ref] == payload[:deployment_repo_git_ref]
    assert workflow_info[:source_repo] == payload[:source_repo]
    assert workflow_info[:source_repo_git_ref] == payload[:source_repo_git_ref]
    assert workflow_info[:source_commit_hash] == payload[:source_commit_hash]
    assert workflow_info[:milestones] == payload[:milestones]
  end  

  test "create_from_payload - existing failed" do
  	:meck.new(Agent, [:passthrough])
  	:meck.expect(Agent, :start_link, fn _ -> {:error, "bad news bears"} end)

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    {result, reason} = Workflow.create_from_payload(payload)
    assert result == :error
    assert reason == "Failed to create Workflow Agent:  \"bad news bears\""
  after
  	:meck.unload(Agent)
  end    

  # ============================
  # get_id tests

  test "get_id" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.get_id(workflow) == id
  end 

  # ============================
  # complete? tests

  test "complete?" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.complete?(workflow) == false
  end

  # ============================
  # resolve_next_milestone tests
  
  test "resolve_next_milestone - no milestones" do
  	:meck.new(NotificationsPublisher, [:passthrough])
  	:meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.resolve_next_milestone(workflow) == :workflow_completed
  after
  	:meck.unload(NotificationsPublisher)
  	:meck.unload(WorkflowAPI)
  end

  test "resolve_next_milestone - no workflow_steps" do
  	:meck.new(NotificationsPublisher, [:passthrough])
  	:meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.resolve_next_milestone(workflow) == :workflow_completed

		workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:workflow_completed] == true    
    assert workflow_info[:workflow_error] == false
    assert workflow_info[:workflow_duration] != nil
    assert workflow_info[:current_step] == :workflow_completed
  after
  	:meck.unload(NotificationsPublisher)
  	:meck.unload(WorkflowAPI)
  end  

  test "resolve_next_milestone - build" do
  	:meck.new(NotificationsPublisher, [:passthrough])
  	:meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [:build],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.resolve_next_milestone(workflow) == :build

		workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:step_time] != nil
    assert workflow_info[:workflow_completed] == false
    assert workflow_info[:workflow_error] == false
    assert workflow_info[:workflow_duration] == nil
    assert workflow_info[:current_step] == :build
  after
  	:meck.unload(NotificationsPublisher)
  	:meck.unload(WorkflowAPI)
  end  

  test "resolve_next_milestone - deploy" do
  	:meck.new(NotificationsPublisher, [:passthrough])
  	:meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [:build, :deploy],
  		current_step: :build
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.resolve_next_milestone(workflow) == :deploy

		workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:step_time] != nil
    assert workflow_info[:workflow_completed] == false
    assert workflow_info[:workflow_error] == false
    assert workflow_info[:workflow_duration] == nil
    assert workflow_info[:workflow_step_durations]["build"] != nil
    assert workflow_info[:current_step] == :deploy
  after
  	:meck.unload(NotificationsPublisher)
  	:meck.unload(WorkflowAPI)
  end  

  # ============================
  # send_success_notification tests

  test "send_success_notification" do
    :meck.new(NotificationsPublisher, [:passthrough])
    :meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)

    updated_info = Workflow.send_success_notification(workflow_info, "hello")
    assert updated_info[:event_log] != nil
    event = List.first(updated_info[:event_log])
    assert event != nil
    assert String.contains?(event, "hello")
  after
    :meck.unload(NotificationsPublisher)
  end

  # ============================
  # send_failure_notification tests

  test "send_failure_notification" do
    :meck.new(NotificationsPublisher, [:passthrough])
    :meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)

    updated_info = Workflow.send_failure_notification(workflow_info, "hello")
    assert updated_info[:event_log] != nil
    event = List.first(updated_info[:event_log])
    assert event != nil
    assert String.contains?(event, "hello")
  after
    :meck.unload(NotificationsPublisher)
  end  

  # ============================
  # send_notification tests

  test "send_notification" do
    :meck.new(NotificationsPublisher, [:passthrough])
    :meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)

    updated_info = Workflow.send_notification(workflow_info, true, "hello")
    assert updated_info[:event_log] != nil
    event = List.first(updated_info[:event_log])
    assert event != nil
    assert String.contains?(event, "hello")
  after
    :meck.unload(NotificationsPublisher)
  end

  # ============================
  # add_event_to_log tests

  test "add_event_to_log" do
    :meck.new(NotificationsPublisher, [:passthrough])
    :meck.expect(NotificationsPublisher, :hipchat_notification, fn _, _, _ -> :ok end)

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)

    updated_info = Workflow.add_event_to_log(workflow_info, true, "hello")
    assert updated_info[:event_log] != nil
    event = List.first(updated_info[:event_log])
    assert event != nil
    assert String.contains?(event, "hello")
  after
    :meck.unload(NotificationsPublisher)
  end  

  # ============================
  # save tests

  test "save - success" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.save(workflow) == :ok
  after
  	:meck.unload(WorkflowAPI)
  end

  test "save - failure" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 400} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  	}

    workflow = Workflow.create_from_payload(payload)
    {status, reason} = Workflow.save(workflow)
    assert status == :error
    assert reason != nil
  after
  	:meck.unload(WorkflowAPI)
  end  

  # ============================
  # resolve_next_step tests
  
  test "resolve_next_step - no milestones" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)
    assert Workflow.resolve_next_step(workflow_info) == nil
  end

  test "resolve_next_step - no workflow_steps" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)
    assert Workflow.resolve_next_step(workflow_info) == nil
  end  

  test "resolve_next_step - build" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [:build],
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)
    assert Workflow.resolve_next_step(workflow_info) == :build
  end  

  test "resolve_next_step - deploy" do
  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		workflow_steps: [:build, :deploy],
  		current_step: :build
  	}

    workflow = Workflow.create_from_payload(payload)
    workflow_info = Workflow.get_info(workflow)
    assert Workflow.resolve_next_step(workflow_info) == :deploy
  end    

  # ============================
  # workflow_failed tests

  test "workflow_failed - success" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 204} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  		current_step: :build
  	}

    workflow = Workflow.create_from_payload(payload)
    assert Workflow.workflow_failed(workflow, "bad news bears") == :ok

		workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:workflow_completed] == true
    assert workflow_info[:workflow_error] == true
    assert workflow_info[:workflow_duration] != nil
    assert workflow_info[:workflow_step_durations]["build"] != nil
  after
  	:meck.unload(WorkflowAPI)
  end

  test "workflow_failed - failure" do
  	:meck.new(WorkflowAPI, [:passthrough])
  	:meck.expect(WorkflowAPI, :update_workflow, fn _, _, _ -> %Response{status: 400} end)  	

  	id = "#{UUID.uuid1()}"
  	payload = %{
  		id: id,
  		workflow_id: id,
  		deployment_repo: "deployment_repo",
  		deployment_repo_git_ref: "deployment_repo_git_ref",
  		source_repo: "source_repo",
  		source_repo_git_ref: "source_repo_git_ref",
  		source_commit_hash: "source_commit_hash",
  		milestones: [:build, :deploy],
  		current_step: :deploy
  	}

    workflow = Workflow.create_from_payload(payload)
    {status, reason} = Workflow.workflow_failed(workflow, "bad news bears")
    assert status == :error
    assert reason != nil

    workflow_info = Workflow.get_info(workflow)
    assert workflow_info != nil
    assert workflow_info[:workflow_completed] == true
    assert workflow_info[:workflow_error] == true
    assert workflow_info[:workflow_duration] != nil
    assert workflow_info[:workflow_step_durations]["deploy"] != nil    
  after
  	:meck.unload(WorkflowAPI)
  end  
end
