isdefined(Base, :__precompile__) && __precompile__()

module DSGE
    using Distributions, HDF5, JLD
    using DataStructures: SortedDict, insert!, ForwardOrdering, OrderedDict
    using FredData, DataFrames, Base.Dates, DistributedArrays
    using QuantEcon: solve_discrete_lyapunov
    import Calculus
    import Optim
    using Optim: OptimizationTrace, OptimizationState, MultivariateOptimizationResults
    using Roots: fzero, ConvergenceFailed

    export

        # distributions_ext.jl
        BetaAlt, GammaAlt, DegenerateMvNormal, DegenerateDiagMvTDist,

        # settings.jl
        Setting, get_setting,

        # defaults.jl
        default_settings!, default_test_settings!,

        # abstractdsgemodel.jl
        AbstractModel, description,
        n_anticipated_shocks, n_anticipated_shocks_padding,
        date_presample_start, date_mainsample_start, date_zlb_start,
        date_presample_end, date_prezlb_end, date_mainsample_end, date_conditional_end,
        index_presample_start, index_mainsample_start, index_zlb_start, index_forecast_start,
        index_shockdec_start,
        n_presample_periods, n_prezlb_periods, n_zlb_periods, n_mainsample_periods,
        n_conditional_periods,
        inds_presample_periods, inds_prezlb_periods, inds_zlb_periods, inds_mainsample_periods,
        n_states, n_states_augmented, n_shocks_exogenous, n_shocks_expectational,
        n_equilibrium_conditions, n_observables, n_parameters, n_parameters_steady_state,
        n_parameters_free, n_pseudoobservables, get_key,
        inds_states_no_ant, inds_shocks_no_ant, inds_obs_no_ant,
        spec, subspec, saveroot, dataroot,
        data_vintage, cond_vintage, cond_id, cond_full_names, cond_semi_names, use_population_forecast,
        use_parallel_workers,
        reoptimize, calculate_hessian, hessian_path, n_hessian_test_params,
        n_mh_blocks, n_mh_simulations, n_mh_burn, mh_thin, n_draws,
        date_forecast_start, date_forecast_end, forecast_tdist_df_val,
        forecast_tdist_shocks, forecast_kill_shocks, forecast_smoother, forecast_zlb_value,
        forecast_input_file_overrides, shockdec_startdate, date_shockdec_end,
        forecast_horizons, impulse_response_horizons,
        load_parameters_from_file, specify_mode!, specify_hessian,
        logpath, workpath, rawpath, tablespath, figurespath, inpath,
        transform_to_model_space!, transform_to_real_line!,

        # parameters.jl
        parameter, Transform, NullablePrior, AbstractParameter,
        Parameter, ParameterVector, ScaledParameter,
        UnscaledParameter, SteadyStateParameter, transform_to_real_line, transform_to_model_space,
        update, update!, transform_to_model_space, transform_to_real_line, Interval, ParamBoundsError,

        # observables.jl
        Observable, PseudoObservable, PseudoObservableMapping,

        # statespace.jl
        Measurement, Transition, System, compute_system,

        # estimate/
        kalman_filter, kalman_filter_2part, likelihood, posterior, posterior!,
        optimize!, csminwel, hessian!, estimate, proposal_distribution,
        metropolis_hastings, compute_parameter_covariance,
        prior,

        # forecast/
        forecast_all, forecast_one,
        load_draws, prepare_systems, compute_system,
        filter, filter_all, filterandsmooth_all, filterandsmooth,
        smooth, smooth_all, kalman_smoother, durbin_koopman_smoother,
        forecast, compute_forecast,
        shock_decompositions, compute_shock_decompositions,
        trends, compute_trends, compute_trend,
        deterministic_trends, compute_deterministic_trends, compute_deterministic_trend,
        impulse_responses, compute_impulse_response,
        get_output_files, read_darray, write_darray, compile_forecast_one,

        # models/
        init_parameters!, steadystate!, init_observable_mappings!,
        Model990, Model1002, SmetsWouters, eqcond, measurement, pseudo_measurement,

        # solve/
        gensys, solve,

        # data/
        load_data, load_data_levels, load_cond_data_levels, load_fred_data,
        transform_data, save_data, get_data_filename,
        df_to_matrix, hpfilter, difflog, quartertodate, percapita, nominal_to_real,
        hpadjust, oneqtrpctchange, annualtoquarter, quartertoannual, quartertoannualpercent,
        logtopct_annualized_percapita, logtopct_annualized, loglevelto4qpct_annualized_percapita,
        loglevelto4qpct_annualized,
        parse_data_series, collect_data_transforms,

        # analysis/
        find_density_bands, moment_tables, means_bands, means_bands_all, compute_means_bands, MeansBands,
        meansbands_matrix_all, meansbands_matrix, read_mb

    const VERBOSITY = Dict(:none => 0, :low => 1, :high => 2)
    const DSGE_DATE_FORMAT = "yymmdd"
    const DSGE_DATASERIES_DELIM = "__"
    const DSGE_SHOCKDEC_DELIM = "__"

    include("parameters.jl")
    include("distributions_ext.jl")
    include("abstractdsgemodel.jl")
    include("settings.jl")
    include("defaults.jl")
    include("observables.jl")
    include("statespace.jl")
    include("util.jl")

    include("data/load_data.jl")
    include("data/fred_data.jl")
    include("data/transformations.jl")
    include("data/transform_data.jl")
    include("data/util.jl")

    include("solve/gensys.jl")
    include("solve/solve.jl")

    include("estimate/kalman.jl")
    include("estimate/posterior.jl")
    include("estimate/optimize.jl")
    include("estimate/csminwel.jl")
    include("estimate/hessian.jl")
    include("estimate/hessizero.jl")
    include("estimate/estimate.jl")

    include("forecast/util.jl")
    include("forecast/smoothers.jl")
    include("forecast/filter.jl")
    include("forecast/smooth.jl")
    include("forecast/forecast.jl")
    include("forecast/shock_decompositions.jl")
    include("forecast/trends.jl")
    include("forecast/deterministic_trends.jl")
    include("forecast/impulse_responses.jl")
    include("forecast/drivers.jl")

    include("analysis/moments.jl")
    include("analysis/meansbands.jl")
    include("analysis/compute_means_bands.jl")
    include("analysis/meansbands_to_matrix.jl")
    include("analysis/util.jl")

    include("models/m990/m990.jl")
    include("models/m990/subspecs.jl")
    include("models/m990/eqcond.jl")
    include("models/m990/observables.jl")
    include("models/m990/measurement.jl")
    include("models/m990/pseudo_measurement.jl")
    include("models/m990/augment_states.jl")

    include("models/m1002/m1002.jl")
    include("models/m1002/subspecs.jl")
    include("models/m1002/eqcond.jl")
    include("models/m1002/observables.jl")
    include("models/m1002/measurement.jl")
    include("models/m1002/pseudo_measurement.jl")
    include("models/m1002/augment_states.jl")

    include("models/smets_wouters/smets_wouters.jl")
    include("models/smets_wouters/subspecs.jl")
    include("models/smets_wouters/eqcond.jl")
    include("models/smets_wouters/measurement.jl")
    include("models/smets_wouters/augment_states.jl")

end
