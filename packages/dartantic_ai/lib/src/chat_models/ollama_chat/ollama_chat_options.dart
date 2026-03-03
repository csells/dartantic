import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';
import 'package:ollama_dart/ollama_dart.dart' show ResponseFormat;

/// Options to pass into Ollama.
@immutable
class OllamaChatOptions extends ChatModelOptions {
  /// Creates a new ollama chat options instance.
  const OllamaChatOptions({
    this.format,
    this.keepAlive,
    this.numKeep,
    this.seed,
    this.numPredict,
    this.topK,
    this.topP,
    this.minP,
    this.tfsZ,
    this.typicalP,
    this.repeatLastN,
    this.repeatPenalty,
    this.presencePenalty,
    this.frequencyPenalty,
    this.mirostat,
    this.mirostatTau,
    this.mirostatEta,
    this.penalizeNewline,
    this.stop,
    this.numa,
    this.numCtx,
    this.numBatch,
    this.numGpu,
    this.mainGpu,
    this.lowVram,
    this.f16KV,
    this.logitsAll,
    this.vocabOnly,
    this.useMmap,
    this.useMlock,
    this.numThread,
    this.logprobs,
    this.topLogprobs,
  });

  /// The format of the response.
  ///
  /// Use [ResponseFormat.json] for JSON mode or [ResponseFormat.schema] for
  /// structured output with a specific JSON schema.
  final ResponseFormat? format;

  /// How long to keep the model loaded in memory (seconds).
  final int? keepAlive;

  /// Number of tokens to keep from the prompt during context swapping.
  final int? numKeep;

  /// The random seed for reproducibility.
  final int? seed;

  /// Maximum number of tokens to predict in the response.
  final int? numPredict;

  /// Limits the next token selection to the K most likely tokens.
  final int? topK;

  /// Nucleus sampling probability threshold.
  final double? topP;

  /// Minimum probability for nucleus sampling.
  final double? minP;

  /// Tail free sampling parameter.
  final double? tfsZ;

  /// Typical sampling parameter.
  final double? typicalP;

  /// Number of last tokens to consider for repetition penalty.
  final int? repeatLastN;

  /// Penalty for repeating tokens.
  final double? repeatPenalty;

  /// Penalty for presence of tokens.
  final double? presencePenalty;

  /// Penalty for frequency of tokens.
  final double? frequencyPenalty;

  /// Mirostat sampling algorithm version.
  final int? mirostat;

  /// Mirostat target entropy.
  final double? mirostatTau;

  /// Mirostat learning rate.
  final double? mirostatEta;

  /// Whether to penalize newlines.
  final bool? penalizeNewline;

  /// List of stop sequences.
  final List<String>? stop;

  /// Whether to use NUMA optimizations.
  final bool? numa;

  /// Context window size (number of tokens).
  final int? numCtx;

  /// Batch size for prompt processing.
  final int? numBatch;

  /// Number of GPUs to use.
  final int? numGpu;

  /// Index of the main GPU to use.
  final int? mainGpu;

  /// Whether to use low VRAM mode.
  final bool? lowVram;

  /// Whether to use 16-bit key-value cache.
  final bool? f16KV;

  /// Whether to return logits for all tokens.
  final bool? logitsAll;

  /// Whether to restrict to vocabulary only.
  final bool? vocabOnly;

  /// Whether to use memory-mapped files.
  final bool? useMmap;

  /// Whether to use memory locking.
  final bool? useMlock;

  /// Number of CPU threads to use.
  final int? numThread;

  /// Whether to return log probabilities of output tokens.
  final bool? logprobs;

  /// Number of most likely tokens to return at each position (requires
  /// logprobs=true).
  final int? topLogprobs;
}
