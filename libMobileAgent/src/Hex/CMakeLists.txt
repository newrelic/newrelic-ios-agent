project(Hex)

set(CMAKE_VERBOSE_MAKEFILE ON)

if(BUILD_FLATBUFFER_SCHEMA)

    set(FBS_DIR ${EXT_PROJECTS_DIR}/mobile_flatbuffer_schemas)

    find_program(FLATBUFFERS_FLATC_EXECUTABLE NAMES flatc)


    set(fbs_glob "*.fbs")

    file(GLOB_RECURSE dependent_schemas ${FBS_DIR}/${fbs_glob})

    set(generated_files "")
    set(generated_includes_dir "${PROJECT_SOURCE_DIR}/include/Hex/generated")

    foreach(schema ${dependent_schemas})
        get_filename_component(filename ${schema} NAME_WE)
        set(generated_include ${generated_includes_dir}/${filename}_generated.h)
        add_custom_command(
                OUTPUT ${generated_include}
                COMMAND "${FLATBUFFERS_FLATC_EXECUTABLE}" --no-includes --gen-mutable --gen-object-api -o "${generated_includes_dir}" -c "${schema}"
                DEPENDS "${FLATBUFFERS_FLATC_EXECUTABLE}" "${schema}"
        )
        list(APPEND generated_files ${generated_include})

    endforeach()
    endif(BUILD_FLATBUFFER_SCHEMA)

    include_directories(
            "include"
            "${CONNECTIVITY_LIBS_DIR}/include"
            "${ANALYTICS_LIBS_DIR}/include"
            "${EXT_PROJECTS_DIR}/flatbuffers/include"
            ${json_SOURCE_DIR}/..
            ${UTILITIES_LIBS_DIR}/include)


    add_library(Hex
            src/HexController.cxx
            src/LibraryController.cxx
            src/report/attributes/BooleanAttributes.cxx
            src/report/attributes/DoubleAttributes.cxx
            src/report/attributes/LongAttributes.cxx
            src/report/attributes/StringAttributes.cxx
            src/report/exception/Frame.cxx
            src/report/exception/HandledException.cxx
            src/report/exception/Library.cxx
            src/report/exception/Thread.cxx
            src/report/AgentData.cxx
            src/report/AppInfo.cxx
            src/HexContext.cxx
            src/HexReportContext.cxx
            src/HexPublisher.cxx
            src/report/ApplicationLicense.cxx
            src/HexAuditor.cxx
            src/report/HexReport.cxx
            src/HexStore.cxx
            src/HexPersistenceManager.cxx)


    add_custom_target(generated_fbs_target DEPENDS ${generated_files})

    add_dependencies(Hex
            generated_fbs_target
            Connectivity
            Analytics
            )


    target_link_libraries(Hex Connectivity Analytics)
