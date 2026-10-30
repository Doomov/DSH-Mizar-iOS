/**
 * Workspaces: the folders under the kernel root that the operator can see.
 *
 * The kernel's root used to keep one fixed `workspace/` directory with a folder
 * per session inside it. It now keeps one folder per *project* directly in the
 * root, and the app points the system file browser at that root, so what is
 * tested here is the contract the Files app depends on: a workspace is a
 * directory with the operator's name on it, a session works inside one, and
 * nothing the kernel writes for itself shows up as a workspace.
 */

import { existsSync, readFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { createKernel } from '../src/index.ts'
import { harness, scriptedEngine, tempRoot } from './helpers/harness.ts'
import { NodeHost } from './helpers/node-host.ts'

interface WorkspaceRow {
  workspaceId: string
  title: string
  path: string
  sessionIds: string[]
}

describe('workspaces', () => {
  it('starts with one default workspace, as a real folder', async () => {
    const h = await harness()
    const list = (await h.call('workspace.list')) as { items: WorkspaceRow[] }
    expect(list.items).toHaveLength(1)
    expect(list.items[0]).toMatchObject({
      workspaceId: 'Default workspace',
      title: 'Default workspace',
      sessionIds: [],
    })
    expect(list.items[0]?.path).toBe(`${h.host.home}/Default workspace`)
    expect(existsSync(join(h.host.root, 'Default workspace'))).toBe(true)
    // The kernel's own bookkeeping is not a workspace.
    expect(existsSync(join(h.host.root, '.mizar', 'config.json'))).toBe(false)
    expect(list.items.map((item) => item.title)).not.toContain('.mizar')
  })

  it('creates one folder per workspace and refuses what cannot be a folder', async () => {
    const h = await harness()
    const created = (await h.call('workspace.create', { name: 'Projects' })) as {
      workspace: WorkspaceRow
    }
    expect(created.workspace).toMatchObject({ title: 'Projects', sessionIds: [] })
    expect(existsSync(join(h.host.root, 'Projects'))).toBe(true)

    const list = (await h.call('workspace.list')) as { items: WorkspaceRow[] }
    expect(list.items.map((item) => item.title)).toEqual(['Default workspace', 'Projects'])

    await expect(h.call('workspace.create', { name: 'Projects' })).rejects.toThrow(/already exists/)
    await expect(h.call('workspace.create', { name: '../escape' })).rejects.toThrow(/folder name/)
    await expect(h.call('workspace.create', { name: '.hidden' })).rejects.toThrow(/folder name/)
    await expect(h.call('workspace.create', { name: '   ' })).rejects.toThrow(/folder name/)
    await expect(h.call('workspace.create', {})).rejects.toThrow(/name/)
  })

  it('starts a session in the workspace it names, and writes there', async () => {
    const h = await harness({
      engine: scriptedEngine([
        { toolCalls: [{ callId: 'c1', name: 'write_file', arguments: '{"path":"notes.md","content":"hello"}' }] },
        { text: 'Written.' },
      ]),
    })
    await h.call('workspace.create', { name: 'Projects' })
    const list = (await h.call('workspace.list')) as { items: WorkspaceRow[] }
    const projects = list.items.find((item) => item.title === 'Projects')
    expect(projects).toBeDefined()

    const created = (await h.call('session.create', { cwd: projects?.path })) as { sessionId: string }
    await h.call('session.prompt', { sessionId: created.sessionId, text: 'write notes' })
    await h.waitTurnDone(created.sessionId)

    expect(readFileSync(join(h.host.root, 'Projects', 'notes.md'), 'utf8')).toBe('hello')
    // The default workspace is untouched: a session works in one folder.
    expect(existsSync(join(h.host.root, 'Default workspace', 'notes.md'))).toBe(false)

    const after = (await h.call('workspace.list')) as { items: WorkspaceRow[] }
    expect(after.items.find((item) => item.title === 'Projects')?.sessionIds).toEqual([
      created.sessionId,
    ])
  })

  it('gives a session with no cwd the default workspace', async () => {
    const h = await harness()
    const created = (await h.call('session.create', {})) as { sessionId: string }
    const list = (await h.call('workspace.list')) as { items: WorkspaceRow[] }
    expect(list.items[0]?.sessionIds).toEqual([created.sessionId])
  })

  it('refuses a cwd that is not a workspace', async () => {
    const h = await harness()
    await expect(h.call('session.create', { cwd: '/etc' })).rejects.toThrow(/no workspace at/)
    await expect(h.call('session.create', { cwd: join(h.host.root, 'nope') })).rejects.toThrow(
      /no workspace at/,
    )
  })

  it('moves a session whose folder disappeared into the default workspace', async () => {
    const root = tempRoot()
    const first = new NodeHost(root)
    const kernel = await createKernel({ host: first })
    await (kernel as unknown as { createWorkspace(name: string): Promise<unknown> }).createWorkspace('Doomed')
    const workspaces = await (kernel as unknown as {
      workspaces(): Promise<{ name: string; path: string }[]>
    }).workspaces()
    const doomed = workspaces.find((item) => item.name === 'Doomed')
    expect(doomed).toBeDefined()
    const store = (kernel as unknown as {
      store: { create(input: { cwd?: string }): Promise<{ sessionId: string }> }
    }).store
    const created = await store.create({ cwd: doomed?.path })

    // The operator deletes the folder from the Files app; the next boot has to
    // put the session somewhere the file tools can actually enter.
    rmSync(join(root, 'Doomed'), { recursive: true, force: true })
    const second = new NodeHost(root)
    const rebooted = await createKernel({ host: second })
    const after = await (rebooted as unknown as {
      workspaces(): Promise<{ name: string; path: string; sessionIds: string[] }[]>
    }).workspaces()
    expect(after.map((item) => item.name)).toEqual(['Default workspace'])
    expect(after[0]?.sessionIds).toEqual([created.sessionId])
  })
})
