/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/spf13/cobra"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.9.0"
	"gopkg.in/telebot.v4"
)

var (
	// TeleToken bot
	TeleToken   = os.Getenv("TELE_TOKEN")
	MetricsHost = os.Getenv("METRICS_HOST")
)

func initTracing(ctx context.Context) {
	log.Printf("Init tracing: %s", MetricsHost)
	// Create a new OTLP Trace gRPC exporter
	traceExporter, err := otlptracegrpc.New(
		ctx,
		otlptracegrpc.WithEndpoint(MetricsHost),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		log.Printf("Failed to create trace exporter: %v", err)
		return
	}

	// Define the resource with attributes that are common to all traces
	resource := resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceNameKey.String(fmt.Sprintf("kbot_%s", appVersion)),
		semconv.ServiceVersionKey.String(appVersion),
	)

	// Create a new TracerProvider with the specified resource and exporter
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(resource),
	)

	// Set the global TracerProvider to the newly created TracerProvider
	otel.SetTracerProvider(tp)
}

func initMetrics(ctx context.Context) {
	log.Printf("Init metrics: %s", MetricsHost)
	// Create a new OTLP Metric gRPC exporter with the specified endpoint and options
	exporter, _ := otlpmetricgrpc.New(
		ctx,
		otlpmetricgrpc.WithEndpoint(MetricsHost),
		otlpmetricgrpc.WithInsecure(),
	)

	// Define the resource with attributes that are common to all metrics.
	// labels/tags/resources that are common to all metrics.
	resource := resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceNameKey.String(fmt.Sprintf("kbot_%s", appVersion)),
	)

	// Create a new MeterProvider with the specified resource and reader
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(resource),
		sdkmetric.WithReader(
			// collects and exports metric data every 10 seconds.
			sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(10*time.Second)),
		),
	)

	// Set the global MeterProvider to the newly created MeterProvider
	otel.SetMeterProvider(mp)

}

func pmetrics(ctx context.Context, payload string) {
	// Get the global MeterProvider and create a new Meter with the name "kbot_light_signal_counter"
	meter := otel.GetMeterProvider().Meter("kbot_light_signal_counter")

	// Get or create an Int64Counter instrument with the name "kbot_light_signal_<payload>"
	counter, _ := meter.Int64Counter(fmt.Sprintf("kbot_light_signal_%s", payload))
	log.Printf("Send metrics: %s", payload)
	// Add a value of 1 to the Int64Counter
	counter.Add(ctx, 1)
}

type TrafficSignal struct {
	Pin int8
	On  bool
}

// kbotCmd represents the kbot command
var kbotCmd = &cobra.Command{
	Use:     "kbot",
	Aliases: []string{"start"},
	Short:   "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		if TeleToken == "" {
			log.Fatal("TELE_TOKEN environment variable is not set")
		}

		fmt.Printf("kbot %s started\n", appVersion)

		kbot, err := telebot.NewBot(telebot.Settings{
			URL:    "",
			Token:  TeleToken,
			Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
		})

		if err != nil {
			log.Fatalf("Please check TELE_TOKEN env variable. %s", err)
		}

		// Initialize traffic signals
		trafficSignals := map[string]*TrafficSignal{
			"red":   {Pin: 12, On: false},
			"amber": {Pin: 27, On: false},
			"green": {Pin: 22, On: false},
		}

		kbot.Handle(telebot.OnText, func(m telebot.Context) error {
			// Create a new span for each message
			tracer := otel.GetTracerProvider().Tracer("kbot")
			ctx, span := tracer.Start(context.Background(), "handle_message")
			defer span.End()

			// Add attributes to the span
			span.SetAttributes(
				semconv.MessagingSystemKey.String("telegram"),
				semconv.MessagingOperationKey.String("receive"),
			)

			log.Printf("Received message: %s", m.Text())
			payload := m.Message().Payload

			// Create a child span for metrics
			_, metricsSpan := tracer.Start(ctx, "send_metrics")
			pmetrics(ctx, payload)
			metricsSpan.End()

			switch payload {
			case "hello":
				span.SetAttributes(semconv.MessagingOperationKey.String("hello_response"))
				return m.Send(fmt.Sprintf("Hello I'm Kbot %s!", appVersion))

			case "red", "amber", "green":
				// Create a child span for traffic signal operation
				_, signalSpan := tracer.Start(ctx, "traffic_signal_operation")
				defer signalSpan.End()

				signalSpan.SetAttributes(
					semconv.MessagingOperationKey.String("traffic_signal"),
					semconv.MessagingDestinationKey.String(payload),
				)

				signal := trafficSignals[payload]

				if !signal.On {
					signal.On = true
					signalSpan.SetAttributes(semconv.MessagingOperationKey.String("turn_on"))
				} else {
					signal.On = false
					signalSpan.SetAttributes(semconv.MessagingOperationKey.String("turn_off"))
				}

				return m.Send(fmt.Sprintf("Switched %s light %s", payload, map[bool]string{true: "on", false: "off"}[signal.On]))

			default:
				span.SetAttributes(semconv.MessagingOperationKey.String("unknown_command"))
				return m.Send("Usage: /s red|amber|green")
			}
		})

		kbot.Start()
	},
}

func init() {
	if MetricsHost != "" {
		initMetrics(context.Background())
		initTracing(context.Background())
	}

	rootCmd.AddCommand(kbotCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// kbotCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// kbotCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
