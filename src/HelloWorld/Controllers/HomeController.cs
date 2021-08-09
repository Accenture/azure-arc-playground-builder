using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Logging;
using HelloWorld.Models;

namespace HelloWorld.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index()
        {
            var httpContextFeatures = HttpContext.Features.Get<IHttpConnectionFeature>();

            var model = new HomeViewModel
            {
                HostIp = $"{httpContextFeatures.LocalIpAddress}",
                HostName = Request.Host.ToString(),
                MachineName = Environment.MachineName,
                OSVersion = Environment.OSVersion.ToString(),
                ProcessorCount = Environment.ProcessorCount.ToString()
            };

            var hosting = Environment.GetEnvironmentVariable("HOSTING_PLATFORM");
            if (!string.IsNullOrWhiteSpace(hosting))
            {
                model.HeaderMessage = $"Hello World, Hosted on {hosting}";
            }
            else
            {
                model.HeaderMessage = "Hello World";
            }

            return View(model);
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
