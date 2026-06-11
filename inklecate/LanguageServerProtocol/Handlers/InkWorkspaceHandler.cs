using System;
using System.Collections.Generic
;
using System.Threading;
using System.Threading.Tasks;
using Ink.LanguageServerProtocol.Backend.Interfaces;
using Ink.LanguageServerProtocol.Workspace.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using OmniSharp.Extensions.LanguageServer.Protocol;
using OmniSharp.Extensions.LanguageServer.Protocol.Client.Capabilities;
using OmniSharp.Extensions.LanguageServer.Protocol.Models;
using OmniSharp.Extensions.LanguageServer.Protocol.Server;
using OmniSharp.Extensions.LanguageServer.Protocol.Server.Capabilities;

namespace Ink.LanguageServerProtocol.Handlers
{
    /// <summary>
    /// Handle workspace requests:
    /// - 'workspace/didChangeConfiguration'
    /// </summary>
    public class InkWorkspaceHandler : DidChangeConfigurationHandler
    {
        private readonly ILogger<InkWorkspaceHandler> _logger;
        private readonly IVirtualWorkspaceManager _virtualWorkspace;
        private readonly IDiagnosticManager _diagnosticManager;

        public InkWorkspaceHandler(
            ILogger<InkWorkspaceHandler> logger,
            IVirtualWorkspaceManager virtualWorkspace,
            IDiagnosticManager diagnosticManager)
        {
            _logger = logger;
            _virtualWorkspace = virtualWorkspace;
            _diagnosticManager = diagnosticManager;
        }

        public async override Task<Unit> Handle(DidChangeConfigurationParams request, CancellationToken cancellationToken)
        {
            _logger.LogDebug("Received 'workspace/didChangeConfiguration'");

            // When configuration changes, recompile all open documents
            // so they can pick up any new settings (e.g., mainFilePath)
            var tasks = new List<Task>();
            foreach (var document in _virtualWorkspace.GetTextDocuments())
            {
                tasks.Add(_diagnosticManager.CompileAndDiagnose(document.Uri, cancellationToken));
            }
            await Task.WhenAll(tasks);

            return Unit.Value;
        }
    }
}
