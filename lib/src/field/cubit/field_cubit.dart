import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A validate function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
typedef Validator<T, E extends Object> = E? Function(T);

/// A async function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
/// The function is debounced by asyncValidatorsDebounceTime.
typedef AsyncValidator<T, E extends Object> = Future<E?> Function(T);

/// A single form field which can be validated.
/// Stores the current value, error text, and whether autovalidate is on.
/// [T] is the held value, [E] is the type of an error. [E] cannot be nullable
/// to be able to unambiguously detect lack of errors.
///
/// If autovalidate is true, the validator will be run after each field change.
// ignore_for_file: avoid_positional_boolean_parameters
class FieldCubit<T, E extends Object> extends Cubit<FieldState<T, E>> {
  /// Creates a new [FieldCubit] with an initial value and a validator.
  FieldCubit({
    required T initialValue,
    Validator<T, E>? validator,
    AsyncValidator<T, E>? asyncValidator,
    this.asyncValidatorsDebounceTime = const Duration(milliseconds: 300),
  })  : _validator = validator ?? ((_) => null),
        _asyncValidator = asyncValidator,
        super(
          FieldState<T, E>(
            value: initialValue,
            error: null,
            autovalidate: false,
            readOnly: false,
            editedManually: false,
          ),
        );

  final Validator<T, E> _validator;

  final AsyncValidator<T, E>? _asyncValidator;

  /// Async validator debounce time.
  final Duration asyncValidatorsDebounceTime;

  /// Async validator debounce timer.
  Timer? _debounceTimer;

  /// Set a new [value]. When [force] is true, [state] is always updated to a new [value],
  /// otherwise if [state] is readonly, [setValue] is a noop
  Future<void> setValue(T value, {bool force = false}) async {
    if (state.readOnly && !force) {
      return;
    }

    E? error;

    if (_asyncValidator != null) {
      unawaited(_runAsyncValidator(value));
    }

    error = state.autovalidate ? _validator(value) : state.error;
    emit(
      FieldState<T, E>(
        value: value,
        error: error,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        editedManually: state.editedManually,
      ),
    );
  }

  /// Returns `null` if field is readonly. Otherwise returns [setValue].
  ///
  /// Useful in contexts where setting `null` as the `onChange` callback causes
  /// the field to be disabled.
  ValueSetter<T>? getValueSetter() {
    if (state.readOnly) {
      return null;
    }

    return setValue;
  }

  /// Emits a [FieldState] with a new [error].
  void setError(E? error) {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: error,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        editedManually: state.editedManually,
      ),
    );
  }

  Future<void> _runAsyncValidator(T value) async {
    // Cancel the previous debounce timer if it exists.
    _debounceTimer?.cancel();

    // Create a new Completer to handle the async validation result.
    final completer = Completer<E?>();

    // Start a new debounce timer.
    _debounceTimer = Timer(asyncValidatorsDebounceTime, () async {
      // Run the async validator and complete the Completer with the result.
      final error = await _asyncValidator!(value);
      completer.complete(error);
    });

    // Wait for the async validation to complete.
    final error = await completer.future;

    // Update the field state with the async validation result.
    emit(
      FieldState<T, E>(
        value: state.value,
        error: error,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        editedManually: state.editedManually,
      ),
    );
  }

  /// Returns true if there are no errors.
  /// If validator returns some error, it is emitted instead.
  /// Only runs sync validator,
  bool validate() {
    final error = _validator(state.value);

    if (error != null) {
      emit(
        FieldState<T, E>(
          value: state.value,
          error: error,
          autovalidate: state.autovalidate,
          readOnly: state.readOnly,
          editedManually: state.editedManually,
        ),
      );
    }

    return state.error == null;
  }

  /// When autovalidate is true, setting a new value will trigger a validation
  void setAutovalidate(bool autovalidate) {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: state.error,
        autovalidate: autovalidate,
        readOnly: state.readOnly,
        editedManually: state.editedManually,
      ),
    );
  }

  /// Sets the [editedManually] flag.
  void setEditedManually(bool editedManually) {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: state.error,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        editedManually: editedManually,
      ),
    );
  }

  /// Prevents further changes of value [T].
  void markReadOnly() {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: state.error,
        autovalidate: state.autovalidate,
        readOnly: true,
        editedManually: state.editedManually,
      ),
    );
  }

  /// Allows further changes of value [T].
  void unmarkReadOnly() {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: state.error,
        autovalidate: state.autovalidate,
        readOnly: false,
        editedManually: state.editedManually,
      ),
    );
  }

  /// Clears all errors on this field.
  void clearErrors() {
    emit(
      FieldState<T, E>(
        value: state.value,
        error: null,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        editedManually: state.editedManually,
      ),
    );
  }
}

/// The state of a [FieldCubit].
class FieldState<T, E extends Object> {
  /// Creates a new [FieldState].
  const FieldState({
    required this.value,
    required this.error,
    required this.autovalidate,
    required this.readOnly,
    required this.editedManually,
  });

  /// Returns true if there are no errors.
  bool get isValid => error == null;

  /// The current value.
  /// Can be set manually by calling [FieldCubit.setValue].
  final T value;

  /// The current error.
  /// If null, the value is considered valid.
  /// Can be set manually by calling [FieldCubit.setError].
  /// Can be cleared by calling [FieldCubit.clearErrors].
  /// Can be set by the validator when [FieldCubit.validate] is called.
  final E? error;

  /// Whether autovalidate is on.
  /// If true, the validator will be run after each field change.
  /// If false, the validator will only be run when [FieldCubit.validate] is called.
  /// Can be changed by calling [FieldCubit.setAutovalidate].
  final bool autovalidate;

  /// Whether the field is readonly.
  /// If true, the value cannot be changed.
  /// Can be changed by calling [FieldCubit.markReadOnly] and [FieldCubit.unmarkReadOnly].
  final bool readOnly;

  /// Whether the field was edited manually.
  /// Can be changed by calling [FieldCubit.setEditedManually].
  final bool editedManually;
}
