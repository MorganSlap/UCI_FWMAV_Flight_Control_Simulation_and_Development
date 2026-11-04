"""Exercise application callbacks, plotting and repeated native runs in Tk."""
from pathlib import Path
import sys
import time
import json
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app import App
import runner
import storage
import configuration as cfg
from scipy.io import loadmat
from tkinter import messagebox

def pump(app, predicate, timeout=20):
    start=time.monotonic()
    while not predicate():
        app.update()
        if time.monotonic()-start>timeout: raise TimeoutError("UI did not complete the requested operation")
        time.sleep(.02)
    app.update()

def main():
    errors=[]
    messagebox.showerror=lambda title,message:errors.append(title+": "+str(message))
    app=App()
    app.report_callback_exception=lambda *args:errors.append(str(args[1]))
    app.update()
    try:
        case=app.collect()
        assert runner.fw_value(case,"angle_p_gain")=="20"
        assert runner.fw_value(case,"gyro_lpf1_static_hz")=="5"
        assert runner.fw_value(case,"acc_lpf_hz")=="5"
        assert case['timing_profile']=='BMI270' and cfg.timing(case)['pid_hz']==3200
        assert case['plant_hz']==16000
        assert tuple(map(int,app.field_widgets['plant_hz'][0]['values']))==cfg.INTEGRATION_RATES
        for rate in cfg.INTEGRATION_RATES:
            app.fields['plant_hz'].set(str(rate)); assert app.collect()['plant_hz']==rate
        app.fields['timing_profile'].set('Custom'); app.select_timing_profile()
        app.fields['gyro.sample_rate'].set('8000'); app.fields['accel.sample_rate'].set('1000')
        app.fw_fields['pid_process_denom'].set('4'); app.fw_fields['imu_process_denom'].set('1')
        assert cfg.timing(app.collect())['pid_hz']==2000
        assert '2000 Hz' in app.timing_summary.get()
        app.fields['timing_profile'].set('BMI270'); app.select_timing_profile()
        assert app.collect()['gyro']['sample_rate']==3200 and app.collect()['accel']['sample_rate']==800
        app.preset('noisy_hover.json')
        app.fw_fields["angle_p_gain"].set("24")
        app.settings_tabs.select(5); app.update()
        assert "set angle_p_gain = 24" in app.cli.get("1.0","end")
        text=app.cli.get("1.0","end").replace("set angle_p_gain = 24","set angle_p_gain = 23")
        app.cli.delete("1.0","end"); app.cli.insert("1.0",text)
        assert runner.fw_value(app.collect(),"angle_p_gain")=="23"
        app.settings_tabs.select(1); app.update()
        assert app.fw_fields["angle_p_gain"].get()=="23"
        app.profile_vars["profile"].set("1"); app.select_profile("profile"); app.update()
        app.fw_fields["angle_p_gain"].set("27")
        app.profile_vars["profile"].set("0"); app.select_profile("profile"); app.update()
        assert app.fw_fields["angle_p_gain"].get()=="23"
        app.profile_vars["profile"].set("1"); app.select_profile("profile"); app.update()
        assert app.fw_fields["angle_p_gain"].get()=="27"
        app.catalog_query.set("imu_dcm_kp"); app.catalog_tree.selection_set("imu_dcm_kp")
        app.catalog_edit.set("3000"); app.apply_catalog(); app.update()
        assert float(app.fields["estimator_kp"].get())==.3
        app.settings_tabs.select(2); app.update()
        assert cfg.firmware_value(app.collect(),"imu_dcm_kp")=="3000"
        app.command_section.set("Receiver map, ranges and failsafe"); app.show_command_section()
        text=app.command_text.get("1.0","end").replace("map AETR1234","map TAER1234")
        app.command_text.delete("1.0","end"); app.command_text.insert("1.0",text); app.apply_command_section()
        assert "map TAER1234" in app.collect()["firmware_cli"]
        app.catalog_preset("angle"); assert len(app.collect()["schedule"])==5
        app.add_command(); assert len(app.collect()["schedule"])==6
        app.remove_command(); assert len(app.collect()["schedule"])==5
        app.catalog_preset("rate"); assert app.collect()["command_mode"]=="rate"
        app.catalog_preset("script_defaults"); runner.validate(app.collect())
        app.preset("noisy_hover.json")
        folders=[]
        for k in range(3):
            app.fields['plant_hz'].set(str((3200,4000,6400)[k]))
            app.fields["duration"].set("0.5"); app.run()
            pump(app,lambda:not app.running,timeout=30)
            pump(app,lambda:app.data is not None and app.data_folder==app.folder,timeout=20)
            folders.append(app.folder)
            assert app.data["time_s"][-1]==.5
            assert app.data.settings['plant_hz']==(3200,4000,6400)[k]
        app.pages.select(1); app.update()
        plot=app.default_plots["True attitude"]
        assert len(plot.series)==3
        plot.limits=(0,.1); plot.home(); assert plot.limits is None and plot.extent()==(0,.5)
        app.search.set("raw_gyro"); app.signals.selection_set(0,2); app.add_signals(); app.update()
        custom=app.explorer.nametowidget(app.explorer.select()); assert len(custom.series)==3
        custom.legend.selection_set(1); custom.clear_selected(); assert len(custom.series)==2
        custom.undock(); app.update()
        app.new_plot(); assert len(app.explorer.tabs())==2
        app.plot_mode.set("Replace active plot"); app.add_signals()
        custom=app.explorer.nametowidget(app.explorer.select()); assert len(custom.series)==3
        app.clear_plot(); assert len(custom.series)==0
        app.angular_plot_units.set("Stored units"); app.add_signals()
        assert np.array_equal(custom.series[0][2],app.data[app.selected_signal_keys()[0]])
        app.close_plot(); assert len(app.explorer.tabs())==1
        app.fields["default_plots"].set(False); app.show_default(); assert not plot.series
        app.fields["default_plots"].set(True); app.show_default(); assert len(plot.series)==3
        for title in app.groups:
            app.default_choice.set(title); app.show_default()
            if title not in ("Estimated position","Estimated velocity"): assert app.default_plots[title].series,title
        for axis in ("Roll","Pitch","Yaw"):
            app.analysis_axis.set(axis); app.draw_analysis()
            assert all(panel["series"] for panel in app.analysis_panels)
            assert "unavailable" not in app.analysis_summary.get().lower()
        output=runner.ROOT/"verification/ui_exports"; output.mkdir(exist_ok=True)
        app.export_analysis(output/"analysis.pdf"); app.export_analysis(output/"analysis.png")
        app.export_signal_csv(output/"csv"); app.export_workspace(output/"selected.mat")
        payload=loadmat(output/"selected.mat"); assert "hoverSignals" in payload
        for key in app.selected_signal_keys():
            exported=np.loadtxt(output/"csv"/(key+".csv"),delimiter=",",skiprows=1)
            assert np.array_equal(exported[:,1],app.data[key])
        for name in ("analysis.pdf","analysis.png","selected.mat","selected.m"): assert (output/name).stat().st_size>100
        app.undock_analysis(); app.undock_defaults(); app.update()
        historical=runner.ROOT.parent/"1_Hover Simulation Work/HoverWorkbench/data/20261019T081116855_tp34b685b4_2faf_427d_a897_ab2bc673f0de"
        if historical.exists():
            old=storage.load_run(historical); assert len(old.signals)>=119
            app.set_data(historical,old); app.draw_analysis()
            assert "unavailable" not in app.analysis_summary.get().lower()
            app.use_record_settings(); runner.validate(app.collect())
        app.preset("noisy_hover.json"); app.fields["duration"].set("1"); app.fields["warmup"].set("60"); app.run()
        pump(app,lambda:app.folder is not None); app.stop(); pump(app,lambda:not app.running,timeout=30)
        assert storage.read_json(app.folder/"engine_summary.json")["stopped"]
        assert not errors,errors
        report={"passed":True,"timing_profile_roundtrip":True,"repeated_runs":3,"pid_cli_roundtrip":True,"profiles_catalog_commands":True,"four_examples_and_script_defaults":True,"default_filters_hz":5,"full_duration_reset":True,"explore_add_and_remove":True,"undock":True,"default_views":len(app.groups),"analysis_axes":3,"analysis_panels":len(app.analysis_plots),"png_pdf_csv_mat_exports":True,"matlab_run_import":historical.exists(),"startup_stop":True,"callback_errors":errors}
        (runner.ROOT/"verification/ui_acceptance.json").write_text(json.dumps(report,indent=2)+"\n")
        print(json.dumps(report,indent=2))
    finally:
        app.stop()
        if app.running: pump(app,lambda:not app.running)
        app.destroy()

if __name__=="__main__": main()
