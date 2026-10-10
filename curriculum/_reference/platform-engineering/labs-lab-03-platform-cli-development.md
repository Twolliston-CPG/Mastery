# Lab 3: Building a Platform CLI Tool

## Lab Overview

In this lab, you will build a command-line interface (CLI) tool for your internal developer platform. The CLI will provide developers with a streamlined way to interact with platform capabilities like creating services, managing environments, and deploying applications.

**Duration:** 3-4 hours
**Difficulty:** Intermediate
**Prerequisites:**
- Go 1.21+ installed
- Git installed
- Docker installed
- Basic Go programming knowledge
- Access to a Kubernetes cluster (optional for full testing)

## Learning Objectives

By the end of this lab, you will be able to:
- Design and implement a platform CLI using Go
- Create intuitive command structures and help systems
- Implement configuration management for CLI tools
- Add interactive prompts for better user experience
- Build and distribute CLI binaries

## Lab Environment Setup

### Step 1: Initialize the Project

```bash
# Create project directory
mkdir platform-cli && cd platform-cli

# Initialize Go module
go mod init github.com/company/platform-cli

# Install dependencies
go get github.com/spf13/cobra@latest
go get github.com/spf13/viper@latest
go get github.com/manifoldco/promptui@latest
go get github.com/fatih/color@latest
go get github.com/olekukonko/tablewriter@latest
go get gopkg.in/yaml.v3@latest
```

### Step 2: Create Project Structure

```bash
mkdir -p cmd/platform
mkdir -p internal/{config,api,service,environment,deploy,util}
mkdir -p pkg/types
```

Project structure:
**`platform-cli/`**

- `cmd/`
  - `platform/`
    - `main.go` — Entry point
- `internal/`
  - `config/`
    - `config.go` — Configuration management
  - `api/`
    - `client.go` — API client
  - `service/`
    - `commands.go` — Service commands
  - `environment/`
    - `commands.go` — Environment commands
  - `deploy/`
    - `commands.go` — Deploy commands
  - `util/`
    - `output.go` — Output formatting
    - `prompt.go` — Interactive prompts
- `pkg/`
  - `types/`
    - `types.go` — Shared types
- `go.mod`
- `go.sum`


## Exercise 1: Core CLI Structure

### Step 1: Create Main Entry Point

Create `cmd/platform/main.go`:

```go
package main

import (
	"os"

	"github.com/company/platform-cli/internal/config"
	"github.com/company/platform-cli/internal/deploy"
	"github.com/company/platform-cli/internal/environment"
	"github.com/company/platform-cli/internal/service"
	"github.com/company/platform-cli/internal/util"
	"github.com/spf13/cobra"
)

var (
	version   = "dev"
	commit    = "none"
	buildDate = "unknown"
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "platform",
		Short: "Platform CLI - Developer platform command line tool",
		Long: `Platform CLI provides a unified interface to interact with
the internal developer platform. Create services, manage environments,
and deploy applications with ease.`,
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	// Global flags
	rootCmd.PersistentFlags().StringP("config", "c", "", "config file (default: ~/.platform/config.yaml)")
	rootCmd.PersistentFlags().StringP("context", "", "", "platform context to use")
	rootCmd.PersistentFlags().StringP("output", "o", "text", "output format (text, json, yaml)")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "verbose output")

	// Initialize configuration
	cobra.OnInitialize(func() {
		configFile, _ := rootCmd.Flags().GetString("config")
		config.Initialize(configFile)
	})

	// Add command groups
	rootCmd.AddCommand(authCmd())
	rootCmd.AddCommand(service.Commands())
	rootCmd.AddCommand(environment.Commands())
	rootCmd.AddCommand(deploy.Commands())
	rootCmd.AddCommand(configCmd())
	rootCmd.AddCommand(versionCmd())

	if err := rootCmd.Execute(); err != nil {
		util.PrintError(err)
		os.Exit(1)
	}
}

func authCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "auth",
		Short: "Authentication commands",
	}

	loginCmd := &cobra.Command{
		Use:   "login",
		Short: "Log in to the platform",
		RunE: func(cmd *cobra.Command, args []string) error {
			util.PrintInfo("Opening browser for authentication...")
			// In real implementation, this would open OAuth flow
			util.PrintSuccess("Successfully logged in!")
			return nil
		},
	}

	logoutCmd := &cobra.Command{
		Use:   "logout",
		Short: "Log out from the platform",
		RunE: func(cmd *cobra.Command, args []string) error {
			util.PrintSuccess("Successfully logged out!")
			return nil
		},
	}

	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show authentication status",
		RunE: func(cmd *cobra.Command, args []string) error {
			util.PrintInfo("Logged in as: user@company.com")
			return nil
		},
	}

	cmd.AddCommand(loginCmd, logoutCmd, statusCmd)
	return cmd
}

func configCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "Configuration management",
	}

	viewCmd := &cobra.Command{
		Use:   "view",
		Short: "View current configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg := config.Get()
			util.PrintYAML(cfg)
			return nil
		},
	}

	setCmd := &cobra.Command{
		Use:   "set KEY VALUE",
		Short: "Set a configuration value",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := config.Set(args[0], args[1]); err != nil {
				return err
			}
			util.PrintSuccess("Configuration updated")
			return nil
		},
	}

	cmd.AddCommand(viewCmd, setCmd)
	return cmd
}

func versionCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			util.PrintInfo("Platform CLI")
			util.PrintKeyValue("Version", version)
			util.PrintKeyValue("Commit", commit)
			util.PrintKeyValue("Build Date", buildDate)
		},
	}
}
```

### Step 2: Create Configuration Management

Create `internal/config/config.go`:

```go
package config

import (
	"os"
	"path/filepath"

	"github.com/spf13/viper"
)

type Config struct {
	APIEndpoint string            `yaml:"api_endpoint" mapstructure:"api_endpoint"`
	Context     string            `yaml:"context" mapstructure:"context"`
	Token       string            `yaml:"token" mapstructure:"token"`
	Team        string            `yaml:"team" mapstructure:"team"`
	Contexts    map[string]Context `yaml:"contexts" mapstructure:"contexts"`
}

type Context struct {
	APIEndpoint string `yaml:"api_endpoint" mapstructure:"api_endpoint"`
	Token       string `yaml:"token" mapstructure:"token"`
}

var cfg *Config

func Initialize(configFile string) {
	if configFile != "" {
		viper.SetConfigFile(configFile)
	} else {
		home, _ := os.UserHomeDir()
		configDir := filepath.Join(home, ".platform")

		// Create config directory if it doesn't exist
		os.MkdirAll(configDir, 0700)

		viper.AddConfigPath(configDir)
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
	}

	// Environment variable overrides
	viper.SetEnvPrefix("PLATFORM")
	viper.AutomaticEnv()

	// Defaults
	viper.SetDefault("api_endpoint", "https://api.platform.internal")
	viper.SetDefault("context", "default")

	// Read config file
	viper.ReadInConfig()

	cfg = &Config{}
	viper.Unmarshal(cfg)
}

func Get() *Config {
	return cfg
}

func Set(key, value string) error {
	viper.Set(key, value)
	return viper.WriteConfig()
}

func GetAPIEndpoint() string {
	return cfg.APIEndpoint
}

func GetToken() string {
	return cfg.Token
}

func GetTeam() string {
	return cfg.Team
}
```

### Step 3: Create Output Utilities

Create `internal/util/output.go`:

```go
package util

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
	"gopkg.in/yaml.v3"
)

var (
	green  = color.New(color.FgGreen).SprintFunc()
	red    = color.New(color.FgRed).SprintFunc()
	yellow = color.New(color.FgYellow).SprintFunc()
	cyan   = color.New(color.FgCyan).SprintFunc()
	bold   = color.New(color.Bold).SprintFunc()
)

func PrintSuccess(message string) {
	fmt.Println(green("✓"), message)
}

func PrintError(err error) {
	fmt.Fprintln(os.Stderr, red("✗"), err.Error())
}

func PrintWarning(message string) {
	fmt.Println(yellow("⚠"), message)
}

func PrintInfo(message string) {
	fmt.Println(cyan("ℹ"), message)
}

func PrintKeyValue(key, value string) {
	fmt.Printf("  %s: %s\n", bold(key), value)
}

func PrintHeader(title string) {
	fmt.Println()
	fmt.Println(bold(title))
	fmt.Println()
}

func PrintTable(headers []string, rows [][]string) {
	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader(headers)
	table.SetBorder(false)
	table.SetHeaderLine(true)
	table.SetColumnSeparator(" ")
	table.AppendBulk(rows)
	table.Render()
}

func PrintJSON(v interface{}) {
	data, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(data))
}

func PrintYAML(v interface{}) {
	data, _ := yaml.Marshal(v)
	fmt.Println(string(data))
}

// Progress indicator for long-running operations
type Progress struct {
	message string
	done    chan bool
}

func NewProgress(message string) *Progress {
	p := &Progress{
		message: message,
		done:    make(chan bool),
	}
	go p.run()
	return p
}

func (p *Progress) run() {
	chars := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	i := 0
	for {
		select {
		case <-p.done:
			return
		default:
			fmt.Printf("\r%s %s ", cyan(chars[i]), p.message)
			i = (i + 1) % len(chars)
			// time.Sleep(100 * time.Millisecond)
		}
	}
}

func (p *Progress) Stop() {
	p.done <- true
	fmt.Print("\r")
}
```

## Exercise 2: Service Commands

### Step 1: Define Types

Create `pkg/types/types.go`:

```go
package types

import "time"

type Service struct {
	Name        string    `json:"name" yaml:"name"`
	Description string    `json:"description" yaml:"description"`
	Owner       string    `json:"owner" yaml:"owner"`
	Repository  string    `json:"repository" yaml:"repository"`
	Tier        string    `json:"tier" yaml:"tier"`
	Status      string    `json:"status" yaml:"status"`
	CreatedAt   time.Time `json:"created_at" yaml:"created_at"`
}

type Environment struct {
	Name      string            `json:"name" yaml:"name"`
	Tier      string            `json:"tier" yaml:"tier"`
	Status    string            `json:"status" yaml:"status"`
	Services  []string          `json:"services" yaml:"services"`
	Resources map[string]string `json:"resources" yaml:"resources"`
	CreatedAt time.Time         `json:"created_at" yaml:"created_at"`
}

type Deployment struct {
	ID          string    `json:"id" yaml:"id"`
	Service     string    `json:"service" yaml:"service"`
	Environment string    `json:"environment" yaml:"environment"`
	Version     string    `json:"version" yaml:"version"`
	Status      string    `json:"status" yaml:"status"`
	StartedAt   time.Time `json:"started_at" yaml:"started_at"`
	CompletedAt time.Time `json:"completed_at" yaml:"completed_at"`
}

type Template struct {
	Name        string   `json:"name" yaml:"name"`
	Description string   `json:"description" yaml:"description"`
	Tags        []string `json:"tags" yaml:"tags"`
}
```

### Step 2: Create Service Commands

Create `internal/service/commands.go`:

```go
package service

import (
	"fmt"
	"strings"
	"time"

	"github.com/company/platform-cli/internal/util"
	"github.com/company/platform-cli/pkg/types"
	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"
)

func Commands() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "service",
		Short: "Manage services",
		Aliases: []string{"svc"},
	}

	cmd.AddCommand(listCmd())
	cmd.AddCommand(createCmd())
	cmd.AddCommand(infoCmd())
	cmd.AddCommand(deleteCmd())

	return cmd
}

func listCmd() *cobra.Command {
	var team string
	var tier string

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List all services",
		Aliases: []string{"ls"},
		RunE: func(cmd *cobra.Command, args []string) error {
			// In real implementation, this would call the API
			services := getMockServices()

			// Filter by team if specified
			if team != "" {
				filtered := []types.Service{}
				for _, s := range services {
					if s.Owner == team {
						filtered = append(filtered, s)
					}
				}
				services = filtered
			}

			// Filter by tier if specified
			if tier != "" {
				filtered := []types.Service{}
				for _, s := range services {
					if s.Tier == tier {
						filtered = append(filtered, s)
					}
				}
				services = filtered
			}

			if len(services) == 0 {
				util.PrintInfo("No services found")
				return nil
			}

			// Format output
			headers := []string{"NAME", "OWNER", "TIER", "STATUS", "REPOSITORY"}
			rows := [][]string{}
			for _, s := range services {
				rows = append(rows, []string{
					s.Name,
					s.Owner,
					s.Tier,
					formatStatus(s.Status),
					s.Repository,
				})
			}

			util.PrintTable(headers, rows)
			return nil
		},
	}

	cmd.Flags().StringVar(&team, "team", "", "filter by team")
	cmd.Flags().StringVar(&tier, "tier", "", "filter by tier (critical, standard, experimental)")

	return cmd
}

func createCmd() *cobra.Command {
	var name string
	var description string
	var owner string
	var template string
	var tier string
	var interactive bool

	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a new service",
		RunE: func(cmd *cobra.Command, args []string) error {
			if interactive || name == "" {
				return createInteractive()
			}

			// Validate required fields
			if name == "" || owner == "" {
				return fmt.Errorf("name and owner are required")
			}

			util.PrintInfo(fmt.Sprintf("Creating service %s...", name))

			// In real implementation, this would call the API
			progress := util.NewProgress("Provisioning resources")
			// Simulate work
			time.Sleep(2 * time.Second)
			progress.Stop()

			util.PrintSuccess(fmt.Sprintf("Service %s created successfully!", name))
			util.PrintKeyValue("Repository", fmt.Sprintf("https://github.com/company/%s", name))
			util.PrintKeyValue("Dashboard", fmt.Sprintf("https://portal.internal/services/%s", name))

			return nil
		},
	}

	cmd.Flags().StringVarP(&name, "name", "n", "", "service name")
	cmd.Flags().StringVarP(&description, "description", "d", "", "service description")
	cmd.Flags().StringVarP(&owner, "owner", "o", "", "owning team")
	cmd.Flags().StringVarP(&template, "template", "t", "go-microservice", "template to use")
	cmd.Flags().StringVar(&tier, "tier", "standard", "service tier")
	cmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "interactive mode")

	return cmd
}

func createInteractive() error {
	util.PrintHeader("Create New Service")

	// Service name
	namePrompt := promptui.Prompt{
		Label:    "Service Name",
		Validate: validateServiceName,
	}
	name, err := namePrompt.Run()
	if err != nil {
		return err
	}

	// Description
	descPrompt := promptui.Prompt{
		Label: "Description",
	}
	description, _ := descPrompt.Run()

	// Template selection
	templates := []types.Template{
		{Name: "go-microservice", Description: "Production-ready Go microservice"},
		{Name: "python-fastapi", Description: "Python FastAPI service"},
		{Name: "node-express", Description: "Node.js Express service"},
		{Name: "react-app", Description: "React frontend application"},
	}

	templateSelect := promptui.Select{
		Label: "Select Template",
		Items: templates,
		Templates: &promptui.SelectTemplates{
			Label:    "{{ . }}",
			Active:   "→ {{ .Name | cyan }} - {{ .Description }}",
			Inactive: "  {{ .Name }} - {{ .Description }}",
			Selected: "✓ {{ .Name | green }}",
		},
	}
	templateIdx, _, err := templateSelect.Run()
	if err != nil {
		return err
	}
	selectedTemplate := templates[templateIdx]

	// Team selection
	teams := []string{"platform-team", "backend-team", "frontend-team", "data-team"}
	teamSelect := promptui.Select{
		Label: "Select Owner Team",
		Items: teams,
	}
	_, owner, err := teamSelect.Run()
	if err != nil {
		return err
	}

	// Tier selection
	tiers := []string{"critical", "standard", "experimental"}
	tierSelect := promptui.Select{
		Label: "Select Service Tier",
		Items: tiers,
	}
	_, tier, err := tierSelect.Run()
	if err != nil {
		return err
	}

	// Confirmation
	fmt.Println()
	util.PrintHeader("Review Configuration")
	util.PrintKeyValue("Name", name)
	util.PrintKeyValue("Description", description)
	util.PrintKeyValue("Template", selectedTemplate.Name)
	util.PrintKeyValue("Owner", owner)
	util.PrintKeyValue("Tier", tier)

	confirmPrompt := promptui.Prompt{
		Label:     "Create service",
		IsConfirm: true,
	}
	_, err = confirmPrompt.Run()
	if err != nil {
		util.PrintWarning("Cancelled")
		return nil
	}

	// Create service
	util.PrintInfo("Creating service...")
	progress := util.NewProgress("Setting up repository")
	time.Sleep(1 * time.Second)
	progress.Stop()

	progress = util.NewProgress("Configuring CI/CD")
	time.Sleep(1 * time.Second)
	progress.Stop()

	progress = util.NewProgress("Creating monitoring")
	time.Sleep(500 * time.Millisecond)
	progress.Stop()

	util.PrintSuccess(fmt.Sprintf("Service %s created successfully!", name))

	fmt.Println()
	util.PrintInfo("Next steps:")
	fmt.Printf("  cd %s\n", name)
	fmt.Printf("  platform deploy start\n")

	return nil
}

func infoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "info NAME",
		Short: "Show service details",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]

			// In real implementation, fetch from API
			service := types.Service{
				Name:        name,
				Description: "Sample service description",
				Owner:       "backend-team",
				Repository:  fmt.Sprintf("https://github.com/company/%s", name),
				Tier:        "standard",
				Status:      "healthy",
				CreatedAt:   time.Now().Add(-30 * 24 * time.Hour),
			}

			util.PrintHeader(fmt.Sprintf("Service: %s", service.Name))
			util.PrintKeyValue("Description", service.Description)
			util.PrintKeyValue("Owner", service.Owner)
			util.PrintKeyValue("Repository", service.Repository)
			util.PrintKeyValue("Tier", service.Tier)
			util.PrintKeyValue("Status", formatStatus(service.Status))
			util.PrintKeyValue("Created", service.CreatedAt.Format("2006-01-02"))

			return nil
		},
	}
}

func deleteCmd() *cobra.Command {
	var force bool

	cmd := &cobra.Command{
		Use:   "delete NAME",
		Short: "Delete a service",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]

			if !force {
				prompt := promptui.Prompt{
					Label:     fmt.Sprintf("Delete service %s", name),
					IsConfirm: true,
				}
				_, err := prompt.Run()
				if err != nil {
					util.PrintWarning("Cancelled")
					return nil
				}
			}

			util.PrintInfo(fmt.Sprintf("Deleting service %s...", name))
			// In real implementation, call API

			util.PrintSuccess(fmt.Sprintf("Service %s deleted", name))
			return nil
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "skip confirmation")

	return cmd
}

// Helper functions

func validateServiceName(input string) error {
	if len(input) < 3 {
		return fmt.Errorf("name must be at least 3 characters")
	}
	if len(input) > 50 {
		return fmt.Errorf("name must be less than 50 characters")
	}
	// Add more validation (alphanumeric, hyphens, etc.)
	return nil
}

func formatStatus(status string) string {
	switch strings.ToLower(status) {
	case "healthy":
		return "✓ Healthy"
	case "degraded":
		return "⚠ Degraded"
	case "failed":
		return "✗ Failed"
	default:
		return status
	}
}

func getMockServices() []types.Service {
	return []types.Service{
		{Name: "payment-service", Owner: "payments-team", Tier: "critical", Status: "healthy", Repository: "github.com/company/payment-service"},
		{Name: "user-service", Owner: "platform-team", Tier: "critical", Status: "healthy", Repository: "github.com/company/user-service"},
		{Name: "order-service", Owner: "orders-team", Tier: "standard", Status: "degraded", Repository: "github.com/company/order-service"},
		{Name: "analytics-api", Owner: "data-team", Tier: "standard", Status: "healthy", Repository: "github.com/company/analytics-api"},
	}
}
```

## Exercise 3: Deploy Commands

Create `internal/deploy/commands.go`:

```go
package deploy

import (
	"fmt"
	"time"

	"github.com/company/platform-cli/internal/util"
	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"
)

func Commands() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "deploy",
		Short: "Deployment commands",
	}

	cmd.AddCommand(startCmd())
	cmd.AddCommand(statusCmd())
	cmd.AddCommand(logsCmd())
	cmd.AddCommand(rollbackCmd())
	cmd.AddCommand(historyCmd())

	return cmd
}

func startCmd() *cobra.Command {
	var env string
	var version string
	var service string
	var wait bool

	cmd := &cobra.Command{
		Use:   "start [SERVICE]",
		Short: "Start a deployment",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Get service name
			if len(args) > 0 {
				service = args[0]
			}
			if service == "" {
				// Try to detect from current directory
				service = detectService()
				if service == "" {
					return fmt.Errorf("service name required")
				}
			}

			// Default environment
			if env == "" {
				env = "staging"
			}

			// Version defaults to latest
			if version == "" {
				version = "latest"
			}

			util.PrintInfo(fmt.Sprintf("Deploying %s to %s...", service, env))

			// Show deployment progress
			steps := []string{
				"Building image",
				"Pushing to registry",
				"Updating deployment",
				"Waiting for pods",
				"Running health checks",
			}

			for i, step := range steps {
				progress := util.NewProgress(fmt.Sprintf("[%d/%d] %s", i+1, len(steps), step))
				time.Sleep(1 * time.Second) // Simulate work
				progress.Stop()
				util.PrintSuccess(step)
			}

			util.PrintSuccess(fmt.Sprintf("Deployment complete!"))
			util.PrintKeyValue("Service", service)
			util.PrintKeyValue("Environment", env)
			util.PrintKeyValue("Version", version)
			util.PrintKeyValue("URL", fmt.Sprintf("https://%s.%s.internal", service, env))

			return nil
		},
	}

	cmd.Flags().StringVarP(&env, "env", "e", "", "target environment")
	cmd.Flags().StringVarP(&version, "version", "V", "", "version to deploy")
	cmd.Flags().BoolVarP(&wait, "wait", "w", true, "wait for deployment to complete")

	return cmd
}

func statusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status [SERVICE]",
		Short: "Show deployment status",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			service := "current-service"
			if len(args) > 0 {
				service = args[0]
			}

			util.PrintHeader(fmt.Sprintf("Deployment Status: %s", service))

			// Mock deployment data
			headers := []string{"ENVIRONMENT", "VERSION", "STATUS", "REPLICAS", "LAST DEPLOY"}
			rows := [][]string{
				{"production", "v1.2.3", "✓ Healthy", "3/3", "2 hours ago"},
				{"staging", "v1.2.4", "✓ Healthy", "2/2", "30 minutes ago"},
				{"development", "v1.2.5", "⚠ Updating", "1/2", "5 minutes ago"},
			}

			util.PrintTable(headers, rows)
			return nil
		},
	}
}

func logsCmd() *cobra.Command {
	var follow bool
	var env string
	var lines int

	cmd := &cobra.Command{
		Use:   "logs [SERVICE]",
		Short: "View deployment logs",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			service := "current-service"
			if len(args) > 0 {
				service = args[0]
			}

			util.PrintInfo(fmt.Sprintf("Showing logs for %s in %s", service, env))

			// Mock log output
			logs := []string{
				"2024-01-15T10:30:00Z INFO  Starting application...",
				"2024-01-15T10:30:01Z INFO  Connected to database",
				"2024-01-15T10:30:01Z INFO  Server listening on :8080",
				"2024-01-15T10:30:15Z INFO  Received health check",
				"2024-01-15T10:30:30Z INFO  Processing request /api/users",
			}

			for _, log := range logs {
				fmt.Println(log)
			}

			if follow {
				util.PrintInfo("Streaming logs... (Ctrl+C to stop)")
			}

			return nil
		},
	}

	cmd.Flags().BoolVarP(&follow, "follow", "f", false, "follow log output")
	cmd.Flags().StringVarP(&env, "env", "e", "staging", "environment")
	cmd.Flags().IntVarP(&lines, "lines", "n", 100, "number of lines")

	return cmd
}

func rollbackCmd() *cobra.Command {
	var env string
	var version string

	cmd := &cobra.Command{
		Use:   "rollback [SERVICE]",
		Short: "Rollback to a previous version",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			service := "current-service"
			if len(args) > 0 {
				service = args[0]
			}

			if version == "" {
				// Show version selection
				versions := []string{"v1.2.3 (current)", "v1.2.2 (1 hour ago)", "v1.2.1 (2 hours ago)", "v1.2.0 (1 day ago)"}
				prompt := promptui.Select{
					Label: "Select version to rollback to",
					Items: versions,
				}
				_, version, _ = prompt.Run()
			}

			confirmPrompt := promptui.Prompt{
				Label:     fmt.Sprintf("Rollback %s to %s", service, version),
				IsConfirm: true,
			}
			_, err := confirmPrompt.Run()
			if err != nil {
				util.PrintWarning("Cancelled")
				return nil
			}

			util.PrintInfo(fmt.Sprintf("Rolling back %s to %s...", service, version))
			time.Sleep(2 * time.Second)
			util.PrintSuccess("Rollback complete!")

			return nil
		},
	}

	cmd.Flags().StringVarP(&env, "env", "e", "staging", "environment")
	cmd.Flags().StringVarP(&version, "version", "V", "", "version to rollback to")

	return cmd
}

func historyCmd() *cobra.Command {
	var env string
	var limit int

	cmd := &cobra.Command{
		Use:   "history [SERVICE]",
		Short: "Show deployment history",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			service := "current-service"
			if len(args) > 0 {
				service = args[0]
			}

			util.PrintHeader(fmt.Sprintf("Deployment History: %s (%s)", service, env))

			headers := []string{"VERSION", "STATUS", "DEPLOYER", "TIMESTAMP", "DURATION"}
			rows := [][]string{
				{"v1.2.4", "✓ Success", "alice@company.com", "2024-01-15 10:30", "4m 23s"},
				{"v1.2.3", "✓ Success", "bob@company.com", "2024-01-14 15:45", "3m 58s"},
				{"v1.2.2", "✗ Failed", "alice@company.com", "2024-01-14 14:30", "2m 15s"},
				{"v1.2.1", "↩ Rollback", "alice@company.com", "2024-01-14 14:15", "1m 30s"},
				{"v1.2.0", "✓ Success", "charlie@company.com", "2024-01-13 09:00", "5m 02s"},
			}

			if limit > 0 && limit < len(rows) {
				rows = rows[:limit]
			}

			util.PrintTable(headers, rows)
			return nil
		},
	}

	cmd.Flags().StringVarP(&env, "env", "e", "staging", "environment")
	cmd.Flags().IntVarP(&limit, "limit", "n", 10, "number of entries to show")

	return cmd
}

func detectService() string {
	// In real implementation, detect from:
	// 1. Current directory name
	// 2. package.json / go.mod
	// 3. catalog-info.yaml
	return ""
}
```

## Exercise 4: Build and Distribution

### Step 1: Create Build Script

Create `Makefile`:

```makefile
VERSION ?= $(shell git describe --tags --always --dirty)
COMMIT ?= $(shell git rev-parse --short HEAD)
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildDate=$(BUILD_DATE)"

.PHONY: build
build:
	go build $(LDFLAGS) -o bin/platform ./cmd/platform

.PHONY: build-all
build-all:
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o bin/platform-darwin-amd64 ./cmd/platform
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o bin/platform-darwin-arm64 ./cmd/platform
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/platform-linux-amd64 ./cmd/platform
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o bin/platform-windows-amd64.exe ./cmd/platform

.PHONY: install
install: build
	cp bin/platform /usr/local/bin/platform

.PHONY: test
test:
	go test -v ./...

.PHONY: lint
lint:
	golangci-lint run

.PHONY: clean
clean:
	rm -rf bin/
```

### Step 2: Build the CLI

```bash
# Build for current platform
make build

# Test it
./bin/platform --help
./bin/platform service list
./bin/platform service create -i
./bin/platform deploy status

# Build for all platforms
make build-all
```

## Verification

### Test All Commands

```bash
# Authentication
./bin/platform auth login
./bin/platform auth status

# Services
./bin/platform service list
./bin/platform service list --team backend-team
./bin/platform service info payment-service
./bin/platform service create -i

# Deployments
./bin/platform deploy start myapp --env staging
./bin/platform deploy status myapp
./bin/platform deploy logs myapp -f
./bin/platform deploy history myapp
./bin/platform deploy rollback myapp

# Configuration
./bin/platform config view
./bin/platform config set team backend-team

# Version
./bin/platform version
```

## Cleanup

```bash
rm -rf bin/
```

## Summary

In this lab, you learned how to:

1. **Structure a CLI application** using Cobra
2. **Create intuitive commands** with proper help and validation
3. **Implement interactive prompts** for better UX
4. **Handle configuration** using Viper
5. **Format output** for both humans and machines
6. **Build and distribute** cross-platform binaries

## Additional Challenges

1. Add shell completion (bash, zsh, fish)
2. Implement actual API client with authentication
3. Add caching for faster repeated operations
4. Create plugin system for extensibility
5. Add telemetry/analytics for usage tracking

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Core CLI Structure
- Service Commands
- Deploy Commands
- Build and Distribution

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The platform makes developers more productive."* |
| ✓ | *"A golden path is a template that produces a repository with CI, manifests, dashboards and alerts already wired, so the product team owns none of them. It reduces cognitive load by removing decisions, not by adding features — and without a documented escape hatch it is a cage."* |

**Trace it:** A developer commits `service.yaml` → a running service with a dashboard and a paging rule. Name every system that acts, and which team owns each one.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Team Topologies — cognitive load](https://teamtopologies.com/key-concepts) and the [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) — why golden paths exist at all.
Full list per domain: [`SOURCES.md`](../SOURCES.md#platform-engineering)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
