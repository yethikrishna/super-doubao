"""Tests covering the three critical bug fixes."""
import asyncio
import inspect
import socket
import threading
import pytest


# ── Fix 1: wait_for_port is defined and works ──────────────────────────────

def _open_ephemeral_server():
    """Bind a real TCP server and return (server_socket, port)."""
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    return srv, srv.getsockname()[1]


@pytest.mark.asyncio
async def test_wait_for_port_returns_true_when_open():
    srv, port = _open_ephemeral_server()
    threading.Thread(target=lambda: srv.accept(), daemon=True).start()
    from application.python_server import wait_for_port
    result = await wait_for_port("127.0.0.1", port, timeout=2.0)
    srv.close()
    assert result is True


@pytest.mark.asyncio
async def test_wait_for_port_returns_false_when_closed():
    from application.python_server import wait_for_port
    result = await wait_for_port("127.0.0.1", 19998, timeout=0.5)
    assert result is False


# ── Fix 2: upload_file_parts accepts max_concurrent argument ───────────────

def test_upload_file_parts_accepts_max_concurrent():
    from application.helpers.utils import upload_file_parts
    sig = inspect.signature(upload_file_parts)
    assert "max_concurrent" in sig.parameters, (
        "upload_file_parts must accept max_concurrent; call site passes it as kwarg"
    )


# ── Fix 3: cydifflib is installable and importable ─────────────────────────

def test_cydifflib_importable():
    try:
        import cydifflib
    except ImportError:
        pytest.fail("cydifflib not installed — add it to requirements_ci.txt")
    assert cydifflib is not None
