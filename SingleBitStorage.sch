<?xml version="1.0" encoding="UTF-8"?>
<drawing version="7">
    <attr value="virtex4" name="DeviceFamilyName">
        <trait delete="all:0" />
        <trait editname="all:0" />
        <trait edittrait="all:0" />
    </attr>
    <netlist>
        <signal name="Clear" />
        <signal name="Output" />
        <signal name="CE" />
        <signal name="Clock" />
        <signal name="Data" />
        <port polarity="Input" name="Clear" />
        <port polarity="Output" name="Output" />
        <port polarity="Input" name="CE" />
        <port polarity="Input" name="Clock" />
        <port polarity="Input" name="Data" />
        <blockdef name="fdce">
            <timestamp>2000-1-1T10:10:10</timestamp>
            <line x2="64" y1="-128" y2="-128" x1="0" />
            <line x2="64" y1="-192" y2="-192" x1="0" />
            <line x2="64" y1="-32" y2="-32" x1="0" />
            <line x2="64" y1="-256" y2="-256" x1="0" />
            <line x2="320" y1="-256" y2="-256" x1="384" />
            <line x2="80" y1="-112" y2="-128" x1="64" />
            <line x2="64" y1="-128" y2="-144" x1="80" />
            <line x2="192" y1="-64" y2="-32" x1="192" />
            <line x2="64" y1="-32" y2="-32" x1="192" />
            <rect width="256" x="64" y="-320" height="256" />
        </blockdef>
        <block symbolname="fdce" name="XLXI_2">
            <blockpin signalname="Clock" name="C" />
            <blockpin signalname="CE" name="CE" />
            <blockpin signalname="Clear" name="CLR" />
            <blockpin signalname="Data" name="D" />
            <blockpin signalname="Output" name="Q" />
        </block>
    </netlist>
    <sheet sheetnum="1" width="3520" height="2720">
        <instance x="912" y="1216" name="XLXI_2" orien="R0" />
        <branch name="CE">
            <wire x2="912" y1="1024" y2="1024" x1="880" />
        </branch>
        <iomarker fontsize="28" x="880" y="1024" name="CE" orien="R180" />
        <branch name="Output">
            <wire x2="1376" y1="960" y2="960" x1="1296" />
        </branch>
        <iomarker fontsize="28" x="1376" y="960" name="Output" orien="R0" />
        <branch name="Clear">
            <wire x2="912" y1="1184" y2="1184" x1="896" />
        </branch>
        <iomarker fontsize="28" x="896" y="1184" name="Clear" orien="R180" />
        <branch name="Clock">
            <wire x2="912" y1="1088" y2="1088" x1="880" />
        </branch>
        <iomarker fontsize="28" x="880" y="1088" name="Clock" orien="R180" />
        <branch name="Data">
            <wire x2="912" y1="960" y2="960" x1="880" />
        </branch>
        <iomarker fontsize="28" x="880" y="960" name="Data" orien="R180" />
    </sheet>
</drawing>