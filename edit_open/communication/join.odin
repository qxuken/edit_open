package communication

import "core:log"
import zmq "edit_open:zeromq"

ADDR_SUB :: #config(EDIT_ADDR_SUB, "tcp://127.0.0.1:53534")
ADDR_RPC :: #config(EDIT_ADDR_RPC, "tcp://127.0.0.1:53535")

Join_Result :: enum {
    Ok,
    Fatal,
    Failed,
}

join_network :: proc(state: ^CommunucationState) -> (ok: bool) {
    switch try_become_leader(state) {
    case .Failed:
        return try_become_follower(state) == .Ok
    case .Fatal:
        return false
    case .Ok:
        return true
    }
    unreachable()
}

try_become_leader :: proc(state: ^CommunucationState) -> (res: Join_Result = .Ok) {
    log.debug("Begin")
    role := Leader {
        publisher_socket = zmq.socket(state.zmq_context, .PUB),
        reply_socket     = zmq.socket(state.zmq_context, .REP),
        poller           = zmq.poller_new(),
    }
    defer if res != .Ok {
        destroy_role(role)
    }
    zmq.poller_add(role.poller, role.reply_socket, nil, .POLLIN)

    log.debug("Bind to SUB")
    if rc := zmq.bind(role.publisher_socket, ADDR_SUB); rc != 0 {
        if zmq.errno() == zmq.EADDRINUSE {
            res = .Failed
            log.debug("zmq.bind(publisher):", zmq.zmq_error_cstring())
        } else {
            res = .Fatal
            log.error("zmq.bind(publisher):", zmq.zmq_error_cstring())
        }
        return
    }
    if !zmq.setsockopt_int(role.publisher_socket, .LINGER, 0) {
        res = .Fatal
        log.error("zmq.setsockopt_string(publisher-LINGER):", zmq.zmq_error_cstring())
        return
    }

    log.debug("Bind to RPC")
    if rc := zmq.bind(role.reply_socket, ADDR_RPC); rc != 0 {
        res = .Fatal
        log.error("zmq.bind(reply):", zmq.zmq_error_cstring())
        return
    }
    if !zmq.setsockopt_int(role.reply_socket, .LINGER, 0) {
        res = .Fatal
        log.error("zmq.setsockopt_string(reply-LINGER):", zmq.zmq_error_cstring())
        return
    }

    udpate_role(state, role)
    log.info("Become leader")
    return
}

try_become_follower :: proc(state: ^CommunucationState) -> (res: Join_Result) {
    log.debug("Begin")
    role := Follower {
        subscriber_socket = zmq.socket(state.zmq_context, .SUB),
        request_socket    = zmq.socket(state.zmq_context, .REQ),
        poller            = zmq.poller_new(),
    }
    defer if res != .Ok {
        destroy_role(role)
    }
    zmq.poller_add(role.poller, role.subscriber_socket, nil, .POLLIN)
    zmq.poller_add(role.poller, role.request_socket, nil, .POLLIN)

    log.debug("Connect to SUB")
    if rc := zmq.connect(role.subscriber_socket, ADDR_SUB); rc != 0 {
        res = .Fatal
        log.error("zmq.connect(subscriber):", zmq.zmq_error_cstring())
        return
    }
    if !zmq.setsockopt_string(role.subscriber_socket, .SUBSCRIBE, "") {
        log.error("zmq.setsockopt_string(subscriber-SUBSCRIBE):", zmq.zmq_error_cstring())
        return .Fatal
    }
    if !zmq.setsockopt_int(role.subscriber_socket, .LINGER, 0) {
        log.error("zmq.setsockopt_string(subscriber-LINGER):", zmq.zmq_error_cstring())
        return .Fatal
    }

    log.debug("Connect to RPC")
    if rc := zmq.connect(role.request_socket, ADDR_RPC); rc != 0 {
        log.error("zmq.connect(request):", zmq.zmq_error_cstring())
        return .Fatal
    }
    if !zmq.setsockopt_string(role.request_socket, .IDENTITY, string(state.id[:])) {
        log.error("zmq.setsockopt_string(request-IDENTITY):", zmq.zmq_error_cstring())
        return .Fatal
    }
    if !zmq.setsockopt_int(role.request_socket, .LINGER, 0) {
        log.error("zmq.setsockopt_string(request-LINGER):", zmq.zmq_error_cstring())
        return .Fatal
    }

    udpate_role(state, role)
    log.info("Become follower")
    return .Ok
}
