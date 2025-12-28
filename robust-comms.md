# Robust Comms Todo Implementation

Task: implement TODOs in `lua/comms.lua`, adjust task typing in `lua/G.lua`, add new frame types in `lua/message/mod.lua`, and update `dispatch.lua`.

## Current State (Completed)

All planned changes have been implemented:

### 1) `lua/message/mod.lua` ✅

- Reordered message types into logical groups (heartbeat, task request lifecycle, task dispatch)
- Added new message types:
  - `task_pending` (0x11) - leader → requester ACK
  - `task_completed` (0x12) - leader → requester success
  - `task_failed` (0x13) - leader → requester failure
  - `task_not_capable` (0x22) - follower → leader
- Added pack functions: `pack_task_pending_frame`, `pack_task_completed_frame`, `pack_task_failed_frame`, `pack_task_not_capable_frame`
- Updated `unpack_frame` to handle all new message types
- Removed garbage text and undefined pack functions (`task_done`, `task_run_failed`)

### 2) `lua/G.lua` ✅

Updated `LeaderTaskEntry` typing with new fields:
- `dispatched_count` - number of peers task was dispatched to
- `not_capable_count` - number of `task_not_capable` responses received
- `dispatch_timer` - timer for dispatch timeout

### 3) `lua/comms.lua` ✅

Implemented all TODOs:

**Constants added:**
- `TASK_DISPATCH_TIMEOUT` (3000ms)

**Leader task request handling:**
- Sends `task_pending` to requester immediately upon receiving request
- If leader can execute locally: executes and sends `task_completed`
- If leader cannot execute locally:
  - Counts peers, fails immediately if none available
  - Sets `dispatched_count`
  - Starts `dispatch_timer`
  - Broadcasts `task_dispatch` to peers

**Leader task_capable handling:**
- Grants first capable peer
- Stops dispatch timer
- Sends `task_granted` to follower
- Sends `task_completed` to requester
- Cleans up task state

**Leader task_not_capable handling (new):**
- Increments `not_capable_count`
- If all dispatched peers responded not capable: sends `task_failed` to requester and cleans up

**Dispatch timeout:**
- Timer fires if still in dispatched state
- Sends `task_failed` to requester
- Cleans up task

**Cleanup improvements:**
- Added `cleanup_task()` helper that clears timers
- `cleanup_role_and_shutdown_socket()` now clears all task timers before closing

**Follower updates:**
- Sends `task_not_capable` when cannot execute (was a TODO)

### 4) `dispatch.lua` ✅

Updated to handle new message types:
- `task_pending`: prints acknowledgement and stores task ID
- `task_completed`: prints success and exits 0
- `task_failed`: prints failure and exits 1
- When not capable: sends `task_not_capable` to leader (instead of exiting immediately)

## Message Flow Summary

### Successful execution by leader:
```
requester → leader: task_request
leader → requester: task_pending
leader executes locally
leader → requester: task_completed
```

### Successful execution by follower:
```
requester → leader: task_request
leader → requester: task_pending
leader → followers: task_dispatch (broadcast)
follower → leader: task_capable
leader → follower: task_granted
leader → requester: task_completed
follower executes
```

### No capable instance:
```
requester → leader: task_request
leader → requester: task_pending
leader → followers: task_dispatch (broadcast)
followers → leader: task_not_capable (all)
leader → requester: task_failed
```

### Timeout (no responses):
```
requester → leader: task_request
leader → requester: task_pending
leader → followers: task_dispatch (broadcast)
... dispatch_timer fires ...
leader → requester: task_failed
```

## Notes

- Completion confirmation from executing follower is not implemented (leader assumes success after granting)
- If strict correctness is needed later, can add `task_done` (follower → leader) flow
- Failure reasons are simple (no detailed enums) - can be extended later if needed