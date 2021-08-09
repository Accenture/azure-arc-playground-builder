using System.Linq;
using HelloWorld.Models;

namespace HelloWorld.Data
{
    public static class TodoDbInitializer
    {
        public static void Initialize(TodoContext context)
        {
            context.Database.EnsureCreated();

            if (context.TodoItems.Any())
            {
                return;
            }

            var todoItems = new TodoItem[]
            {
                new TodoItem { Name = "Build the cluster", IsComplete = false },
                new TodoItem { Name = "Connect the cluster to Azure Arc", IsComplete = false },
                new TodoItem { Name = "Install App Service Extensions on Azure Arc connected cluster", IsComplete = false },
                new TodoItem { Name = "Create a custom location", IsComplete = false },
                new TodoItem { Name = "Create an App Service Kubernetes Environment", IsComplete = false },
                new TodoItem { Name = "Create an App Service Plan", IsComplete = false },
                new TodoItem { Name = "Create an App Service", IsComplete = false },
                new TodoItem { Name = "Deploy Hello World code.", IsComplete = false },
                new TodoItem { Name = "Admire Azure App Service running in Kubernetes.", IsComplete = false },
            };

            context.AddRange(todoItems);

            context.SaveChanges();
        }
    }
}