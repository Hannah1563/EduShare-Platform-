# compute module

One Ubuntu 24.04 VM with SSH-key login only (no passwords) and VM extensions disabled. Used twice by the root module:

- **bastion**: `assign_public_ip = true`, in the public subnet.
- **app**: `assign_public_ip = false`, in the private subnet.

Outputs: `vm_id`, `vm_name`, `public_ip` (null for a private VM), `private_ip`.
